#include <metal_stdlib>
using namespace metal;

struct Arguments {
	texture2d<float> documentViewTexture;
	float2 documentViewOrigin;
	float2 documentViewSize;
	float2 resolution;
};

struct RasterizerData {
	float4 position [[position]];
	float2 textureCoordinates;
};

constant float2 corners[] = {
        float2(0, 0),
        float2(1, 0),
        float2(1, 1),
        float2(1, 1),
        float2(0, 1),
        float2(0, 0),
};

vertex RasterizerData VertexMain(ushort vertex_id [[vertex_id]], constant Arguments &arguments) {
	RasterizerData output = {};

	float2 corner = corners[vertex_id];

	float2 position = arguments.documentViewOrigin + corner * arguments.documentViewSize;
	position /= arguments.resolution;
	position *= 2;
	position -= 1;
	output.position = float4(position, 0, 1);

	output.textureCoordinates = corner;
	output.textureCoordinates.y = 1 - output.textureCoordinates.y;

	return output;
}

fragment float4 FragmentMain(RasterizerData input [[stage_in]], constant Arguments &arguments) {
	constexpr sampler s(filter::nearest);
	return arguments.documentViewTexture.sample(s, input.textureCoordinates);
}
