// PocketFrame private-room adapter. GPL-3.0-or-later, like this frontend.
#include <atomic>
#include <cstdio>
#include <regex>
#include "core/core.h"
#include "core/hle/service/cfg/cfg.h"
#include "core/loader/loader.h"
#include "core/hle/kernel/kernel.h"
#include "core/hle/kernel/shared_page.h"
#include "network/network.h"
#include "network/verify_user.h"
#ifdef _WIN32
#define PF_EXPORT extern "C" __declspec(dllexport)
#else
#define PF_EXPORT extern "C" __attribute__((visibility("default")))
#endif
namespace {
bool initialized=false;
std::atomic<int> state{1}, members{0}, error{-1}, hosting{0};
Network::RoomMember::CallbackHandle<Network::RoomMember::State> state_callback;
Network::RoomMember::CallbackHandle<Network::RoomMember::Error> error_callback;
Network::RoomMember::CallbackHandle<Network::RoomInformation> info_callback;
}
// All control calls belong to the emulation worker. Callbacks only publish
// atomic values: neither Godot nor the worker reads live ENet member vectors.
PF_EXPORT void pocketframe_network_shutdown() {
    if (!initialized) return;
    Network::Shutdown();
    state_callback.reset(); error_callback.reset(); info_callback.reset();
    initialized=false; state=1; members=0; hosting=0;
}
PF_EXPORT int pocketframe_network_initialize() {
    if(initialized) return 0;
    if(!Network::Init()) return -2;
    initialized=true;
    auto member=Network::GetRoomMember().lock();
    state_callback=member->BindOnStateChanged([](const auto& s){state=static_cast<int>(s);if(state<3)members=0;});
    error_callback=member->BindOnError([](const auto& e){error=static_cast<int>(e);});
    info_callback=member->BindOnRoomInformationChanged([](const auto&){
        if(auto m=Network::GetRoomMember().lock()) members=static_cast<int>(m->GetMemberInformation().size());
    });
    return 0;
}
PF_EXPORT int pocketframe_network_command(int mode, const char* nickname,
    const char* address, unsigned port, const char* password, const char* test_identity) {
    if (mode<0 || mode>2 || port<1 || port>65535) return -1;
    if (mode && (!nickname || !std::regex_match(nickname,std::regex("^[ a-zA-Z0-9._-]{4,20}$")))) return -1;
    if(pocketframe_network_initialize()<0)return -2;
    auto member=Network::GetRoomMember().lock();
    // Preserve the RoomMember object: nwm::UDS subscribed during game boot.
    member->Leave();
    auto room=Network::GetRoom().lock();
    if(room->GetState()==Network::Room::State::Open)room->Destroy();
    error=-1;members=0;hosting=0;
    if(!mode)return 0;
    const std::string pass=password?password:"";
    if(mode==1) {
        // Deliberately private: no public lobby, web tokens, UPnP or router changes.
        const char* bind_address=(test_identity && *test_identity)?"127.0.0.1":"";
        if(!Network::GetRoom().lock()->Create("PocketFrame private game","Local wireless over a private connection",bind_address,static_cast<u16>(port),pass,4,"","",0,std::make_unique<Network::VerifyUser::NullBackend>())) {
            return -3;
        }
        hosting=1;
    }
    auto& system=Core::System::GetInstance();
    // Real games use their actual console identity. Explicit isolated probes
    // may supply a dummy identity, without opening or modifying any profile.
    const std::string identity=system.IsPoweredOn()?Service::CFG::GetConsoleIdHash(system):(test_identity?test_identity:"");
    if(identity.empty()){if(hosting){room->Destroy();hosting=0;}return -4;}
    member->Join(nickname,identity,mode==1?"127.0.0.1":address,static_cast<u16>(port),0,Network::NoPreferredMac,pass);
    if(system.IsPoweredOn()) {
        u64 id=0; std::string title;
        system.GetAppLoader().ReadProgramId(id);
        system.GetAppLoader().ReadTitle(title,true);
        member->SendGameInfo({title,id});
    }
    return 0;
}
PF_EXPORT void pocketframe_network_status(char* buffer, unsigned capacity) {
    auto& system=Core::System::GetInstance();
    if(system.IsPoweredOn() && state>=3) {
        if(auto member=Network::GetRoomMember().lock();member && member->IsConnected())
            system.Kernel().GetSharedPageHandler().SetMacAddress(member->GetMacAddress());
    }
    if(buffer && capacity) std::snprintf(buffer,capacity,"%d|%d|%d|%d",state.load(),members.load(),error.load(),hosting.load());
}
