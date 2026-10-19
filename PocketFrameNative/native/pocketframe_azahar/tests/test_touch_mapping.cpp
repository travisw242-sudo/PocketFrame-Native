#include "touch_mapping.hpp"
#include <cstdio>

int main() {
    int failures = 0;
    // Mirror Azahar MouseTracker::Update's pointer decode, including truncation.
    // Check every native touchscreen pixel, plus both rendering scales.
    for (bool stereo : {false, true}) for (int scale : {1, 2}) for (int y=0; y<240; ++y) for (int x=0; x<320; ++x) {
        const auto p = pocketframe::bottom_lcd_pointer(x/319.f, y/239.f, stereo);
        const int px = int((p.x + 32767) / 65534.f * ((stereo ? 800 : 400)*scale));
        const int py = int((p.y + 32767) / 65534.f * (480*scale));
        if ((px-40*scale)/scale != x || (py-240*scale)/scale != y ||
            px<40*scale || px>=360*scale || py<240*scale || py>=480*scale) ++failures;
    }
    std::printf("Touch mapping: 307200 mono/stereo pixel checks, %d failures\n", failures);
    return failures ? 1 : 0;
}
