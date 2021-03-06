/*\
 * Program Description:
 * Downsample & Horizontal blur for Bloom
\*/

//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

const bool colortex5MipmapEnabled = true;
#define samplerName colortex5

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D samplerName;

//--// Custom uniforms

uniform vec2 viewPixelSize;

#if defined STAGE_VERTEX
	//--// Vertex Outputs //--------------------------------------------------//

	out vec2 screenCoord;

	//--// Vertex Functions //------------------------------------------------//

	void main() {
		screenCoord = gl_Vertex.xy;
		gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs //-------------------------------------------------//

	in vec2 screenCoord;

	//--// Fragment Outputs //------------------------------------------------//

	/* DRAWBUFFERS:6 */

	layout (location = 0) out vec3 color;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility.glsl"
	#include "/include/utility/encoding.glsl"

	#include "/include/shared/blurTileOffset.glsl"

	//--// Fragment Functions //----------------------------------------------//

	float Gaussian(float x, float sigma) {
		return exp(-(x * x) / (2.0 * sigma * sigma)) * inversesqrt(tau * sigma * sigma);
	}
	#define Gaussian_c(x, sigma) (exp(-(x * x) / (2.0 * sigma * sigma)) * inversesqrt(tau * sigma * sigma))

	float CalcFastBlurOffset(float o1, float o2, float w1, float w2) {
		return (o1 * w1 + o2 * w2) / (w1 + w2);
	}
	#define CalcFastBlurOffset_c(o1, o2, w1, w2) ((o1 * w1 + o2 * w2) / (w1 + w2))

	vec3 HorizontalBlur(vec2 coord, const float lod) {
		if (Clamp01(coord) != coord) { return vec3(0.0); }

		#define SIGMA 3.0
		const float[7] weights = float[7](
			Gaussian_c(0, SIGMA),
			Gaussian_c(1, SIGMA) + Gaussian_c(2, SIGMA),
			Gaussian_c(3, SIGMA) + Gaussian_c(4, SIGMA),
			Gaussian_c(5, SIGMA) + Gaussian_c(6, SIGMA),
			Gaussian_c(7, SIGMA) + Gaussian_c(8, SIGMA),
			Gaussian_c(9, SIGMA) + Gaussian_c(10, SIGMA),
			Gaussian_c(11, SIGMA) + Gaussian_c(12, SIGMA)
		);
		const float[7] offsets = float[7](
			0.0,
			CalcFastBlurOffset_c( 1,  2, Gaussian_c( 1, SIGMA), Gaussian_c( 2, SIGMA)),
			CalcFastBlurOffset_c( 3,  4, Gaussian_c( 3, SIGMA), Gaussian_c( 4, SIGMA)),
			CalcFastBlurOffset_c( 5,  6, Gaussian_c( 5, SIGMA), Gaussian_c( 6, SIGMA)),
			CalcFastBlurOffset_c( 7,  8, Gaussian_c( 7, SIGMA), Gaussian_c( 8, SIGMA)),
			CalcFastBlurOffset_c( 9, 10, Gaussian_c( 9, SIGMA), Gaussian_c(10, SIGMA)),
			CalcFastBlurOffset_c(11, 12, Gaussian_c(11, SIGMA), Gaussian_c(12, SIGMA))
		);

		float offsetScale = viewPixelSize.x * exp2(lod);

		vec3 tile = textureLod(samplerName, coord, lod).rgb * weights[0];
		for (int i = 1; i < 7; i++) {
			float sampleOffset = offsets[i] * offsetScale;
			tile += textureLod(samplerName, vec2(coord.x + sampleOffset, coord.y), lod).rgb * weights[i];
			tile += textureLod(samplerName, vec2(coord.x - sampleOffset, coord.y), lod).rgb * weights[i];
		}
		return tile;
	}

	void main() {
		#ifndef BLOOM
			discard;
		#endif

		color = HorizontalBlur(screenCoord * exp2(1), 1);
		for (int i = 1; i < 7; ++i) {
			color += HorizontalBlur((screenCoord - CalculateTileOffset(i)) * exp2(i + 1), i + 1);
		}
	}
#endif
