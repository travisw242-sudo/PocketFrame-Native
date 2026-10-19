#pragma once

#include <libretro_vulkan.h>
#include <mutex>
#include <vector>
class PFAzaharCore;

// Owns the LibRetro-facing Vulkan objects. Azahar creates the logical device
// through its negotiation callback; PocketFrame owns the instance and device
// lifetime, as required by the LibRetro Vulkan protocol.
class PFVulkanHost {
    VkInstance instance_ = VK_NULL_HANDLE;
    VkPhysicalDevice gpu_ = VK_NULL_HANDLE;
    VkDevice device_ = VK_NULL_HANDLE;
    VkQueue queue_ = VK_NULL_HANDLE;
    uint32_t queue_family_ = 0;
    VkImage latest_image_ = VK_NULL_HANDLE;
    VkImageLayout latest_layout_ = VK_IMAGE_LAYOUT_UNDEFINED;
    VkFormat latest_format_ = VK_FORMAT_UNDEFINED;
    retro_hw_render_interface_vulkan interface_{};
    std::mutex queue_mutex_;
    std::vector<VkSemaphore> waits_;
    VkSemaphore signal_ = VK_NULL_HANDLE;
    VkCommandPool pool_ = VK_NULL_HANDLE;
    VkCommandBuffer command_ = VK_NULL_HANDLE;
    VkFence fence_ = VK_NULL_HANDLE;
    VkBuffer staging_ = VK_NULL_HANDLE;
    VkDeviceMemory memory_ = VK_NULL_HANDLE;
    void *mapped_ = nullptr;
    size_t staging_size_ = 0;
    std::vector<uint8_t> cpu_pixels_;

    static void set_image(void *handle, const retro_vulkan_image *image,
                          uint32_t semaphore_count, const VkSemaphore *semaphores,
                          uint32_t source_queue_family);
    static uint32_t get_sync_index(void *handle);
    static uint32_t get_sync_index_mask(void *handle);
    static void wait_sync_index(void *handle);
    static void lock_queue(void *handle);
    static void unlock_queue(void *handle);
    static void set_signal(void *handle, VkSemaphore semaphore);

public:
    ~PFVulkanHost();
    bool initialize(const retro_hw_render_context_negotiation_interface_vulkan *negotiation);
    void destroy();
    bool readback(PFAzaharCore *core, unsigned width, unsigned height);
    const retro_hw_render_interface_vulkan *get_interface() const { return &interface_; }
    bool ready() const { return device_ != VK_NULL_HANDLE; }
    VkImage latest_image() const { return latest_image_; }
    VkImageLayout latest_layout() const { return latest_layout_; }
    VkFormat latest_format() const { return latest_format_; }
};
