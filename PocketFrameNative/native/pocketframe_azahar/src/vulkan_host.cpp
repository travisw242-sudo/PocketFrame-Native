#include "vulkan_host.hpp"
#include "azahar_core.hpp"
#include <dlfcn.h>
#include <cstring>
#include <stdexcept>

#include <algorithm>
#include <vector>

// Load from the graphics driver's installed loader; no SDK install required.
#define PF_VK_FUNCTIONS(X) \
 X(vkGetInstanceProcAddr) X(vkGetDeviceProcAddr) X(vkCreateInstance) \
 X(vkEnumeratePhysicalDevices) X(vkGetPhysicalDeviceProperties) \
 X(vkDeviceWaitIdle) X(vkDestroyDevice) X(vkDestroyInstance) \
 X(vkCreateCommandPool) X(vkDestroyCommandPool) X(vkAllocateCommandBuffers) \
 X(vkCreateFence) X(vkDestroyFence) X(vkWaitForFences) X(vkResetFences) \
 X(vkCreateBuffer) X(vkDestroyBuffer) X(vkGetBufferMemoryRequirements) \
 X(vkGetPhysicalDeviceMemoryProperties) X(vkAllocateMemory) X(vkFreeMemory) \
 X(vkBindBufferMemory) X(vkMapMemory) X(vkUnmapMemory) X(vkResetCommandBuffer) \
 X(vkBeginCommandBuffer) X(vkEndCommandBuffer) X(vkCmdPipelineBarrier) \
 X(vkCmdCopyImageToBuffer) X(vkQueueSubmit) X(vkQueueWaitIdle)
#define PF_DECLARE(name) static PFN_##name name = nullptr;
PF_VK_FUNCTIONS(PF_DECLARE)
#undef PF_DECLARE
static bool load_vulkan() {
    static void* loader = dlopen("libvulkan.so.1",RTLD_NOW|RTLD_LOCAL);
    if (!loader) return false;
#define PF_LOAD(name) name = reinterpret_cast<PFN_##name>(dlsym(loader, #name)); if (!name) return false;
    PF_VK_FUNCTIONS(PF_LOAD)
#undef PF_LOAD
    return true;
}

PFVulkanHost::~PFVulkanHost() { destroy(); }

bool PFVulkanHost::initialize(const retro_hw_render_context_negotiation_interface_vulkan *negotiation) {
    if (!negotiation || !negotiation->get_application_info || !negotiation->create_device)
        return false;
    if (!load_vulkan()) return false;
    destroy();

    const VkApplicationInfo *app = negotiation->get_application_info();
    VkApplicationInfo fallback{VK_STRUCTURE_TYPE_APPLICATION_INFO};
    fallback.pApplicationName = "PocketFrame";
    fallback.apiVersion = VK_API_VERSION_1_1;
    VkInstanceCreateInfo create_info{VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO};
    create_info.pApplicationInfo = app ? app : &fallback;
    // The core asks for swapchain on its device, which depends on surface.
    const char *extensions[] = {VK_KHR_SURFACE_EXTENSION_NAME};
    create_info.enabledExtensionCount = 1;
    create_info.ppEnabledExtensionNames = extensions;
    if (vkCreateInstance(&create_info, nullptr, &instance_) != VK_SUCCESS)
        return false;

    uint32_t count = 0;
    if (vkEnumeratePhysicalDevices(instance_, &count, nullptr) != VK_SUCCESS || count == 0) {
        destroy(); return false;
    }
    std::vector<VkPhysicalDevice> devices(count);
    vkEnumeratePhysicalDevices(instance_, &count, devices.data());
    // Prefer a discrete GPU (the SteamVR/Godot device on this PC), otherwise
    // accept the first Vulkan-capable adapter.
    gpu_ = devices.front();
    for (VkPhysicalDevice candidate : devices) {
        VkPhysicalDeviceProperties properties{};
        vkGetPhysicalDeviceProperties(candidate, &properties);
        if (properties.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) { gpu_ = candidate; break; }
    }

    retro_vulkan_context context{};
    if (!negotiation->create_device(&context, instance_, gpu_, VK_NULL_HANDLE,
                                    vkGetInstanceProcAddr, nullptr, 0, nullptr, 0, nullptr)) {
        destroy(); return false;
    }
    gpu_ = context.gpu; device_ = context.device; queue_ = context.queue;
    queue_family_ = context.queue_family_index;
    if (!device_ || !queue_) { destroy(); return false; }
    VkCommandPoolCreateInfo pool_info{VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO};
    pool_info.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    pool_info.queueFamilyIndex = queue_family_;
    if (vkCreateCommandPool(device_, &pool_info, nullptr, &pool_) != VK_SUCCESS) { destroy(); return false; }
    VkCommandBufferAllocateInfo alloc{VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
    alloc.commandPool = pool_; alloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY; alloc.commandBufferCount = 1;
    if (vkAllocateCommandBuffers(device_, &alloc, &command_) != VK_SUCCESS) { destroy(); return false; }
    VkFenceCreateInfo fence_info{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
    if (vkCreateFence(device_, &fence_info, nullptr, &fence_) != VK_SUCCESS) { destroy(); return false; }

    interface_ = {};
    interface_.interface_type = RETRO_HW_RENDER_INTERFACE_VULKAN;
    interface_.interface_version = RETRO_HW_RENDER_INTERFACE_VULKAN_VERSION;
    interface_.handle = this;
    interface_.instance = instance_;
    interface_.gpu = gpu_;
    interface_.device = device_;
    interface_.get_device_proc_addr = vkGetDeviceProcAddr;
    interface_.get_instance_proc_addr = vkGetInstanceProcAddr;
    interface_.queue = queue_;
    interface_.queue_index = queue_family_;
    interface_.set_image = set_image;
    interface_.get_sync_index = get_sync_index;
    interface_.get_sync_index_mask = get_sync_index_mask;
    interface_.wait_sync_index = wait_sync_index;
    interface_.lock_queue = lock_queue;
    interface_.unlock_queue = unlock_queue;
    interface_.set_signal_semaphore = set_signal;
    return true;
}

void PFVulkanHost::destroy() {
    if (device_) vkDeviceWaitIdle(device_);
    if (mapped_) vkUnmapMemory(device_, memory_);
    if (staging_) vkDestroyBuffer(device_, staging_, nullptr);
    if (memory_) vkFreeMemory(device_, memory_, nullptr);
    if (fence_) vkDestroyFence(device_, fence_, nullptr);
    if (pool_) vkDestroyCommandPool(device_, pool_, nullptr);
    if (device_) vkDestroyDevice(device_, nullptr);
    if (instance_) vkDestroyInstance(instance_, nullptr);
    instance_ = VK_NULL_HANDLE; gpu_ = VK_NULL_HANDLE; device_ = VK_NULL_HANDLE;
    queue_ = VK_NULL_HANDLE; latest_image_ = VK_NULL_HANDLE;
    latest_layout_ = VK_IMAGE_LAYOUT_UNDEFINED; latest_format_ = VK_FORMAT_UNDEFINED;
    interface_ = {};
    staging_ = VK_NULL_HANDLE; memory_ = VK_NULL_HANDLE; mapped_ = nullptr; staging_size_ = 0;
    pool_ = VK_NULL_HANDLE; command_ = VK_NULL_HANDLE; fence_ = VK_NULL_HANDLE;
    waits_.clear(); signal_ = VK_NULL_HANDLE;
}

void PFVulkanHost::set_image(void *handle, const retro_vulkan_image *image, uint32_t count,
                              const VkSemaphore *semaphores, uint32_t family) {
    auto *host = static_cast<PFVulkanHost *>(handle);
    if (!host || !image) return;
    if (family != VK_QUEUE_FAMILY_IGNORED && family != host->queue_family_)
        throw std::runtime_error("Vulkan core returned an unexpected queue family");
    host->waits_.clear();
    if (count) host->waits_.assign(semaphores, semaphores + count);
    host->latest_image_ = image->create_info.image;
    host->latest_layout_ = image->image_layout;
    host->latest_format_ = image->create_info.format;
}
uint32_t PFVulkanHost::get_sync_index(void *) { return 0; }
uint32_t PFVulkanHost::get_sync_index_mask(void *) { return 1; }
void PFVulkanHost::wait_sync_index(void *) {}
void PFVulkanHost::lock_queue(void *handle) { static_cast<PFVulkanHost *>(handle)->queue_mutex_.lock(); }
void PFVulkanHost::unlock_queue(void *handle) { static_cast<PFVulkanHost *>(handle)->queue_mutex_.unlock(); }
void PFVulkanHost::set_signal(void *handle, VkSemaphore semaphore) { static_cast<PFVulkanHost *>(handle)->signal_ = semaphore; }

bool PFVulkanHost::readback(PFAzaharCore *core, unsigned width, unsigned height) {
    if (!ready() || !latest_image_ || !width || !height || width > 4096 || height > 4096) return false;
    const size_t bytes = static_cast<size_t>(width) * height * 4;
    if (bytes != staging_size_) {
        vkDeviceWaitIdle(device_);
        if (mapped_) vkUnmapMemory(device_, memory_);
        if (staging_) vkDestroyBuffer(device_, staging_, nullptr);
        if (memory_) vkFreeMemory(device_, memory_, nullptr);
        mapped_ = nullptr; memory_ = VK_NULL_HANDLE; staging_ = VK_NULL_HANDLE;
        VkBufferCreateInfo info{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
        info.size = bytes; info.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT;
        if (vkCreateBuffer(device_, &info, nullptr, &staging_) != VK_SUCCESS) return false;
        VkMemoryRequirements requirements{}; vkGetBufferMemoryRequirements(device_, staging_, &requirements);
        VkPhysicalDeviceMemoryProperties properties{}; vkGetPhysicalDeviceMemoryProperties(gpu_, &properties);
        uint32_t type = UINT32_MAX;
        for (uint32_t i = 0; i < properties.memoryTypeCount; ++i)
            if ((requirements.memoryTypeBits & (1u << i)) &&
                (properties.memoryTypes[i].propertyFlags & (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)) ==
                (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)) {
                type = i;
                if (properties.memoryTypes[i].propertyFlags & VK_MEMORY_PROPERTY_HOST_CACHED_BIT) break;
            }
        if (type == UINT32_MAX) return false;
        VkMemoryAllocateInfo allocation{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO}; allocation.allocationSize = requirements.size; allocation.memoryTypeIndex = type;
        if (vkAllocateMemory(device_, &allocation, nullptr, &memory_) != VK_SUCCESS ||
            vkBindBufferMemory(device_, staging_, memory_, 0) != VK_SUCCESS ||
            vkMapMemory(device_, memory_, 0, bytes, 0, &mapped_) != VK_SUCCESS) return false;
        staging_size_ = bytes;
    }
    vkResetCommandBuffer(command_, 0);
    VkCommandBufferBeginInfo begin{VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO}; begin.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    if (vkBeginCommandBuffer(command_, &begin) != VK_SUCCESS) return false;
    VkImageMemoryBarrier barrier{VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
    barrier.srcAccessMask = VK_ACCESS_MEMORY_WRITE_BIT; barrier.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
    barrier.oldLayout = latest_layout_; barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    barrier.srcQueueFamilyIndex = barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier.image = latest_image_; barrier.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
    vkCmdPipelineBarrier(command_, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 0, nullptr, 1, &barrier);
    VkBufferImageCopy copy{}; copy.imageSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1}; copy.imageExtent = {width, height, 1};
    vkCmdCopyImageToBuffer(command_, latest_image_, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, staging_, 1, &copy);
    barrier.srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT; barrier.dstAccessMask = VK_ACCESS_MEMORY_READ_BIT | VK_ACCESS_MEMORY_WRITE_BIT;
    barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL; barrier.newLayout = latest_layout_;
    vkCmdPipelineBarrier(command_, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, 0, 0, nullptr, 0, nullptr, 1, &barrier);
    VkBufferMemoryBarrier host_barrier{VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER};
    host_barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT; host_barrier.dstAccessMask = VK_ACCESS_HOST_READ_BIT;
    host_barrier.srcQueueFamilyIndex = host_barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    host_barrier.buffer = staging_; host_barrier.size = VK_WHOLE_SIZE;
    vkCmdPipelineBarrier(command_, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_HOST_BIT, 0, 0, nullptr, 1, &host_barrier, 0, nullptr);
    if (vkEndCommandBuffer(command_) != VK_SUCCESS) return false;
    std::vector<VkPipelineStageFlags> stages(waits_.size(), VK_PIPELINE_STAGE_TRANSFER_BIT);
    VkSubmitInfo submit{VK_STRUCTURE_TYPE_SUBMIT_INFO}; submit.commandBufferCount = 1; submit.pCommandBuffers = &command_;
    submit.waitSemaphoreCount = static_cast<uint32_t>(waits_.size()); submit.pWaitSemaphores = waits_.data(); submit.pWaitDstStageMask = stages.data();
    if (signal_) { submit.signalSemaphoreCount = 1; submit.pSignalSemaphores = &signal_; }
    vkResetFences(device_, 1, &fence_);
    { std::lock_guard lock(queue_mutex_); if (vkQueueSubmit(queue_, 1, &submit, fence_) != VK_SUCCESS) return false; }
    waits_.clear(); signal_ = VK_NULL_HANDLE;
    if (vkWaitForFences(device_, 1, &fence_, VK_TRUE, 5000000000ULL) != VK_SUCCESS) return false;
    // Preserve the actual renderer resolution. Sharp submits 800x960;
    // reducing it to 400x480 here discarded its extra detail before VR.
    // Mapped GPU/BAR memory can be uncached. Do a single sequential copy
    // before channel conversion, instead of hundreds of thousands of PCIe reads.
    cpu_pixels_.resize(bytes);
    std::memcpy(cpu_pixels_.data(), mapped_, bytes);
    const bool rgba = latest_format_ == VK_FORMAT_R8G8B8A8_UNORM || latest_format_ == VK_FORMAT_R8G8B8A8_SRGB;
    // The presenter can consume RGBA directly; do not swap channels here
    // only for the main thread to swap them back again.
    core->receive_frame(cpu_pixels_.data(), width, height, static_cast<size_t>(width) * 4, rgba);
    return true;
}
