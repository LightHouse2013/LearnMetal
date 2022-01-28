//
//  DefaultShader.metal
//  Lesson2-DrawImage
//
//  Created by zhang.wenhai on 2022/1/27.
//

#include <metal_stdlib>
using namespace metal;

struct RasterizerData {
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex RasterizerData basic_vertex(constant packed_float3* vertices[[buffer(0)]],
                                   constant packed_float2* textureCoordinates[[buffer(1)]],
                                   uint vid[[vertex_id]]) {
    RasterizerData out;
    out.position = float4(vertices[vid], 1.0);
    out.textureCoordinate = float2(textureCoordinates[vid]);
    return out;
}

fragment float4 basic_fragment(RasterizerData in [[stage_in]],
                               texture2d<half> colorTexture[[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    half4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);
    return float4(colorSample);
}

