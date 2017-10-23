Shader "AFS/Grass Shader (instanced)" {
Properties {
	_MainTex ("Albedo (RGB) Alpha (A)", 2D) = "white" {}
	_Cutoff ("Alpha cutoff", Range(0,1)) = 0.3
	[NoScaleOffset] _BumpTransSpecMap ("Translucency (G) Occlusion (B)", 2D) = "white" {}
	_SmoothnessMin ("Min Smoothness", Range(0,1)) = 0.2
	_SmoothnessMax ("Max Smoothness", Range(0,1)) = 0.6

	[HideInInspector] CRITIAS_MaxFoliageTypeDistance("Max Foliage Type Distance Default", Float) = 100
}


SubShader {
	Tags {
//		"Queue" = "Geometry+200"
		"Queue"="AlphaTest" // needed for lightmapper
		"IgnoreProjector"="True"
		"RenderType"="AFSGrass"
		"AfsMode"="Grass"
	}
	Cull Off
	LOD 200

CGPROGRAM
#pragma surface surf AFSSpecular vertex:AfsWavingGrassVert addshadow nodynlightmap nolightmap


#define AFSMANUALGRASS
#define AFSCRITIASGRASS

struct appdata_grass {
	float4 vertex : POSITION;
float4 tangent : TANGENT;
	float3 normal : NORMAL;
	float3 texcoord : TEXCOORD0;
	//float2 texcoord1 : TEXCOORD1;
	//float2 texcoord2 : TEXCOORD2;
	fixed4 color : COLOR;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

// CRITIAS
#pragma multi_compile_instancing
#pragma instancing_options assumeuniformscaling force_same_maxcount_for_gl

#include "TerrainEngine.cginc"
#include "Includes/AfsWavingGrass.cginc"
#include "Includes/AfsPBSLighting.cginc"


sampler2D _MainTex;
float _Cutoff;
sampler2D _BumpTransSpecMap;
fixed _SmoothnessMin;
fixed _SmoothnessMax;
// Global vars
fixed 	_AfsRainamount;

struct Input {
	float2 uv_MainTex;
	float4 color : COLOR;
};

void AfsWavingGrassVert (inout appdata_grass v, out Input o) 
{
	UNITY_INITIALIZE_OUTPUT(Input,o);

	#if defined(AFSCRITIASGRASS)
		float3 worldPos = float3(unity_ObjectToWorld[0].w, unity_ObjectToWorld[1].w, unity_ObjectToWorld[2].w);
		float DistanceToCam = distance(worldPos, _WorldSpaceCameraPos);
		float maxDist = CRITIAS_MaxFoliageTypeDistance - DISTANCE_SCALE_BIAS;
		if (DistanceToCam <= CRITIAS_MaxFoliageTypeDistance) {
			float dist = 1.0 - clamp(DistanceToCam - maxDist, 0.0, DISTANCE_SCALE_BIAS) / DISTANCE_SCALE_BIAS;
			v.vertex.xyz *= dist;

			v.normal = UnityObjectToWorldNormal(float3(0, 1, 0));
			float waveAmount = v.color.a * _AfsWaveAndDistance.z;

			// doing the animation in worldspace will give us less contrast between manually placed grass
			// and grass within the terrain engine
			v.vertex = mul(unity_ObjectToWorld, v.vertex);
			// TODO: why texcoord.zz? because of depth pass?
			v.color = WaveGrass(v.vertex, v.normal, waveAmount, v.color, v.texcoord.zz); // v.color.rr); ////v.texcoord1.xy);
			v.vertex = mul(unity_WorldToObject, v.vertex);

			v.color.rgb = half3(1, 1, 1);

		}
		else {
			v.vertex.y -= 10000;
		}
	#endif
}


void surf (Input IN, inout SurfaceOutputAFSSpecular o) {
	fixed4 c = tex2D(_MainTex, IN.uv_MainTex);
	o.Alpha = c.a; // *IN.color.a; // As we scale down instances!
	// Do early alpha test
	clip (o.Alpha - _Cutoff);

	fixed4 d = tex2D(_BumpTransSpecMap, IN.uv_MainTex.xy);
	o.Albedo = c.rgb * IN.color.rgb;
	o.Albedo *= lerp(1.0, 0.5, _AfsRainamount); // We do not use the standard value here as grass does not get much reflections
	
	// o.Specular is inititialized as 0.0 -> lambert lighting
	
	o.Translucency = d.g;
	o.Smoothness = lerp(_SmoothnessMin, _SmoothnessMax, _AfsRainamount) * d.g * IN.color.r; // this brings in some ambient reflections
	o.Occlusion = d.b;
}
ENDCG
}
	Fallback "Legacy Shaders/Transparent/Cutout/Diffuse"
}