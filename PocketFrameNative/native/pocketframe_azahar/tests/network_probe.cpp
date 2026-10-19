// Uses the exact shipped DLL through its C ABI; no games or profiles touched.
#include <windows.h>
#include <libretro.h>
#include <chrono>
#include <thread>
#include <cstdio>
#include <cstdlib>
#include <cstring>
static void log_message(enum retro_log_level,const char*,...) {}
static bool environment(unsigned command,void* data) {
    if(command==RETRO_ENVIRONMENT_GET_LOG_INTERFACE) {
        static_cast<retro_log_callback*>(data)->log=log_message;return true;
    }
    return false;
}
int main(int argc,char** argv) {
    if(argc<7)return 2;
    HMODULE module=LoadLibraryA(argv[1]);if(!module)return 3;
    auto set_env=reinterpret_cast<void(*)(retro_environment_t)>(GetProcAddress(module,"retro_set_environment"));
    auto init=reinterpret_cast<void(*)()>(GetProcAddress(module,"retro_init"));
    auto deinit=reinterpret_cast<void(*)()>(GetProcAddress(module,"retro_deinit"));
    auto command=reinterpret_cast<int(*)(int,const char*,const char*,unsigned,const char*,const char*)>(GetProcAddress(module,"pocketframe_network_command"));
    auto status=reinterpret_cast<void(*)(char*,unsigned)>(GetProcAddress(module,"pocketframe_network_status"));
    if(!set_env||!init||!deinit||!command||!status)return 4;
    set_env(environment);init();
    int mode=std::atoi(argv[2]);int expected_error=std::atoi(argv[6]);
    int result=command(mode,argv[4],"127.0.0.1",std::atoi(argv[3]),argv[5],argv[4]);
    bool passed=expected_error<-1 && result==expected_error;
    if(result==0)for(int i=0;i<150;i++) {
        char buffer[96]{};status(buffer,sizeof(buffer));
        int state=0,members=0,error=-1,hosting=0;
        std::sscanf(buffer,"%d|%d|%d|%d",&state,&members,&error,&hosting);
        if((expected_error>=0 && error==expected_error) || (expected_error<0 && state>=3 && members>=2)) {
            std::printf("PASS %s: %s\n",argv[4],buffer);passed=true;
            // Keep host alive long enough for the peer to observe both members.
            if(mode==1)std::this_thread::sleep_for(std::chrono::seconds(5));
            if(mode==2 && expected_error<0) {
                command(0,"","",24872,"","");
                command(2,argv[4],"127.0.0.1",std::atoi(argv[3]),argv[5],argv[4]);
                passed=false;
                for(int retry=0;retry<30;retry++) {
                    status(buffer,sizeof(buffer));
                    std::sscanf(buffer,"%d|%d|%d|%d",&state,&members,&error,&hosting);
                    if(state>=3 && members>=2){passed=true;std::puts("PASS reconnect");break;}
                    std::this_thread::sleep_for(std::chrono::milliseconds(100));
                }
            }
            break;
        }
        if(error>=0 && error!=expected_error){std::printf("Unexpected error %d\n",error);break;}
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    command(0,"","",24872,"","");deinit();FreeLibrary(module);
    return passed?0:5;
}
