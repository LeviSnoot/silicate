// Vertex shader

struct VertexInput {
    [[location(0)]] position: vec3<f32>;
    [[location(1)]] tex_coords: vec2<f32>;
};

struct VertexOutput {
    [[builtin(position)]] clip_position: vec4<f32>;
    [[location(0)]] tex_coords: vec2<f32>;
};

[[stage(vertex)]]
fn vs_main(
    model: VertexInput
) -> VertexOutput {
    var out: VertexOutput;
    out.tex_coords = model.tex_coords;
    out.clip_position = vec4<f32>(model.position, 1.0);
    return out;
}
 
// Fragment shader

fn comps(c: f32, a: f32) -> f32 {
    return c * (1.0 - a);
}

fn comp(c: vec3<f32>, a: f32) -> vec3<f32> {
    return c * (1.0 - a);
}

fn normal(c1: vec3<f32>, c2: vec3<f32>, _: f32, a2: f32) -> vec3<f32> {
    return c2 + comp(c1, a2);
}

fn multiply(c1: vec3<f32>, c2: vec3<f32>, a1: f32, a2: f32) -> vec3<f32> {
    return c2 * c1 + comp(c2, a1) + comp(c1, a2);
}

fn screen(c1: vec3<f32>, c2: vec3<f32>, _: f32, _: f32) -> vec3<f32> {
    return c2 + c1 - c2 * c1;
}

fn overlay(c1: f32, c2: f32, a1: f32, a2: f32) -> f32 {
    if (c1 * 2.0 <= a1) {
        return c2 * c1 * 2.0 + comps(c2, a1) + comps(c1, a2);
    } else {
        return comps(c2, a1) + comps(c1, a2) - 2.0 * (a1 - c1) * (a2 - c2) + a2 * a1;
    }
}

struct CtxInput {
    opacity: f32;
    blend: u32;
};

[[group(0), binding(0)]]
var splr: sampler;
[[group(1), binding(0)]]
var composite: texture_2d<f32>;
[[group(1), binding(1)]]
var clipping_mask: texture_2d<f32>;
[[group(1), binding(2)]]
var layer: texture_2d<f32>;
[[group(1), binding(3)]]
var<uniform> ctx: CtxInput;

[[stage(fragment)]]
fn fs_main(in: VertexOutput) -> [[location(0)]] vec4<f32> {
    var fg = textureSample(layer, splr, in.tex_coords);
    var maska = textureSample(clipping_mask, splr, in.tex_coords).a;
    fg.a = min(fg.a, maska);

    let bg = textureSample(composite, splr, in.tex_coords);
    fg.a = fg.a * ctx.opacity;

    fg = select(fg, vec4<f32>(0.0), fg.a == 0.0);

    var final_pixel = vec3<f32>(0.0);

    switch (ctx.blend) {
        case 1: {
            final_pixel = multiply(bg.rgb, fg.rgb, bg.a, fg.a);
        }
        case 2: {
            final_pixel = screen(bg.rgb, fg.rgb, bg.a, fg.a);
        }
        case 11: {
            final_pixel = vec3<f32>(overlay(bg.r, fg.r, bg.a, fg.a), overlay(bg.g, fg.g, bg.a, fg.a), overlay(bg.b, fg.b, bg.a, fg.a));
        }
        default: {
            final_pixel = normal(bg.rgb, fg.rgb, bg.a, fg.a);
        }
    }

    return vec4<f32>(final_pixel, bg.a + fg.a - bg.a * fg.a);
}
