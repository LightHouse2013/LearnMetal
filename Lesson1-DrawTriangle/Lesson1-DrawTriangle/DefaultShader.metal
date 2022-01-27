//
//  DefaultShader.metal
//  Lesson1-DrawTriangle
//
//  Created by zhang.wenhai on 2022/1/27.
//

#include <metal_stdlib>
using namespace metal;

struct RasterizerData {
    // The [[position]] attribute of this member indicates that this value
    // is the clip space position of the vertex when this structure is
    // returned from the vertex function.
    float4 position [[position]];

    // Since this member does not have a special attribute, the rasterizer
    // interpolates its value with the values of the other triangle vertices
    // and then passes the interpolated value to the fragment shader for each
    // fragment in the triangle.
    float4 color;
};

vertex RasterizerData basic_vertex(constant packed_float3* vertices[[buffer(0)]],
                           constant packed_float4* colors[[buffer(1)]],
                           uint vid[[vertex_id]]) {
    RasterizerData out;
    out.position = float4(vertices[vid], 1.0);
    out.color = float4(colors[vid]);
    return out;
}

fragment float4 basic_fragment(RasterizerData in [[stage_in]]) {
    return in.color;
}

