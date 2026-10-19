#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

#include "azahar_core.hpp"

using namespace godot;

void initialize_pocketframe_azahar(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        GDREGISTER_CLASS(PFAzaharCore);
    }
}

void uninitialize_pocketframe_azahar(ModuleInitializationLevel) {}

extern "C" GDExtensionBool GDE_EXPORT pocketframe_azahar_init(
        GDExtensionInterfaceGetProcAddress get_proc_address,
        GDExtensionClassLibraryPtr library,
        GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
    init.register_initializer(initialize_pocketframe_azahar);
    init.register_terminator(uninitialize_pocketframe_azahar);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
