#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>

namespace pocketframe {
struct TouchPointer { int16_t x, y; };
// Same upright 400x480 stack that receive_frame crops into two LCDs:
// bottom LCD is [40,360) x [240,480). LibRetro pointers address the WHOLE
// stack, not just the bottom image. Use pixel centers to keep edges in bounds.
inline TouchPointer bottom_lcd_pointer(float u, float v, bool stereo = false) {
    const float x = (40.5f + std::clamp(u, 0.f, 1.f) * 319.f) / (stereo ? 800.f : 400.f);
    const float y = (240.5f + std::clamp(v, 0.f, 1.f) * 239.f) / 480.f;
    return {static_cast<int16_t>(std::lround(x * 65534.f - 32767.f)),
            static_cast<int16_t>(std::lround(y * 65534.f - 32767.f))};
}
}
