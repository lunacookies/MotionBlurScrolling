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

struct Fragment {
	float4 subframeColor [[color(0)]];
	float4 accumulationColor [[color(1)]];
	float4 outputColor [[color(2)]];
};

struct ClearArguments {
	float4 clearColor;
};

fragment Fragment Clear(Fragment frag, constant ClearArguments &arguments) {
	frag.subframeColor = arguments.clearColor;
	return frag;
}

fragment Fragment Accumulate(Fragment frag) {
	float4 color = frag.subframeColor;
	color.rgb /= color.a;
	color.rgb = pow(color.rgb, 2.2);
	frag.accumulationColor += color;
	return frag;
}

struct DivideArguments {
	float subframeCount;
};

fragment Fragment Divide(Fragment frag, constant DivideArguments &arguments) {
	frag.outputColor = frag.accumulationColor / arguments.subframeCount;
	frag.outputColor.rgb = pow(frag.outputColor.rgb, 1.f / 2.2);
	frag.outputColor.rgb *= frag.outputColor.a;
	return frag;
}
