Shader "mainShader"
{
    Properties
    {
        [NoScaleOffset]positonMap ("positonMap", 2D) = "white" {}
        [NoScaleOffset] normalMap ("normalMap (RGB)", 2D) = "white" {}
        _lerp ("lerp", Range(0,1)) = 0
        _tess ("tess", Range(4,320)) = 8
        _mipBias("mipBias", Range(-8,8)) = 0
        _maxDist("maxDist", Range(1, 100)) = 32
        _maxMip("maxMip", Range(0, 16)) = 16
        [Toggle(_NORM)] _Norm ("Use normal map", Float) = 0
    }
    SubShader
    {
        Tags {"LightMode"="ForwardBase" "RenderType" = "Opaque" }
        LOD 100
        
        Pass
        {            
            Cull Off //hackzzz
        
            CGPROGRAM
            #pragma vertex VS
            #pragma fragment PS
            #pragma hull HS
            #pragma domain DS
            #pragma target 5.0        
            
            #pragma shader_feature _NORM
        
            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"
            #include "Tessellation.cginc"
            #include "Lighting.cginc"
            
            UNITY_DECLARE_TEX2D(positonMap);
            float4 positonMap_TexelSize;
            
            UNITY_DECLARE_TEX2D( normalMap);
            float4 normalMap_TexelSize;
            
            float _lerp, _tess, _mipBias, _maxDist, _maxMip;          
            
            struct vertex_t 
            {
                float2 texcoord : TEXCOORD0;
                fixed4 color : COLOR0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
            };            
            
            
            
            
            
            
           
            float CalcMip(float4 texSize) 
            {
                float4 mm = mul(UNITY_MATRIX_M, float4(_maxDist, _maxDist, _maxDist, 1));
                float dist = length(_WorldSpaceCameraPos) / mm;
                dist *= 1 + ceil(log2(max(texSize.z, texSize.w)));
                dist -= _mipBias;
                dist = clamp(dist, 0, _maxMip);
                return dist;
            }
            
            float4 GetPosition(float2 uvs)
            {
                 float dist = CalcMip(positonMap_TexelSize);   
                 float4 c = positonMap.SampleLevel(samplerpositonMap, uvs, dist);
                 return c;
             } 
             
            float4 GetNormal(float2 uvs)
            {
                float dist = CalcMip(normalMap_TexelSize);        
                float4 n = normalMap.SampleLevel(samplernormalMap, uvs, dist);
                return n;
            } 
                
           
            vertex_t displacement (vertex_t v)
            {
                vertex_t o;
                
                float2 uvs = v.texcoord.xy;
                o.vertex = UnityObjectToClipPos(float4( lerp( v.vertex.xyz, GetPosition(uvs), _lerp), 1));          
#ifdef _NORM
                o.normal = lerp( v.normal, GetNormal(uvs), _lerp);
#else
                o.normal = v.normal;
#endif           
                o.texcoord = v.texcoord;
                half nl = max(0, dot(o.normal, _WorldSpaceLightPos0.xyz));
                o.color = nl * _LightColor0;
                o.color.rgb += ShadeSH9(half4(o.normal,1));
                return o;
            }           
            
            
            
            
            
            
            
            
            
            
            

            vertex_t VS (appdata_base v)
            {
                vertex_t o;
                o.vertex = v.vertex;
                o.normal = v.normal;
                o.texcoord = v.texcoord;   
                o.color = float4(1, 1, 1, 1);
                return o;
            }
            
            fixed4 PS (vertex_t i) : SV_Target
            {
                fixed4 col = UNITY_SAMPLE_TEX2D(positonMap, i.texcoord);
                col *= i.color;
                return col;
            }

            [UNITY_domain("tri")]
            vertex_t DS (UnityTessellationFactors tessFactors, const OutputPatch<vertex_t,3> vi, float3 bary : SV_DomainLocation) 
            {
                vertex_t v;
                UNITY_INITIALIZE_OUTPUT(vertex_t,v);
                v.vertex = vi[0].vertex*bary.x + vi[1].vertex*bary.y + vi[2].vertex*bary.z;
                v.normal = vi[0].normal*bary.x + vi[1].normal*bary.y + vi[2].normal*bary.z;
                v.texcoord = vi[0].texcoord*bary.x + vi[1].texcoord*bary.y + vi[2].texcoord*bary.z;
                v.color = vi[0].color*bary.x + vi[1].color*bary.y + vi[2].color*bary.z;
                return displacement(v);
            }

            UnityTessellationFactors HS_PCF (InputPatch<vertex_t,3> v)
            {
                UnityTessellationFactors o;
                float4 tf;
                vertex_t vi[3];
                vi[0].vertex = v[0].vertex;
                vi[0].normal = v[0].normal;
                vi[0].texcoord = v[0].texcoord;
                vi[0].color = v[0].color;
                vi[1].vertex = v[1].vertex;
                vi[1].normal = v[1].normal;
                vi[1].texcoord = v[1].texcoord;
                vi[1].color = v[1].color;
                vi[2].vertex = v[2].vertex;
                vi[2].normal = v[2].normal;
                vi[2].texcoord = v[2].texcoord;
                vi[2].color = v[2].color;
                tf = UnityEdgeLengthBasedTess (vi[0].vertex, vi[1].vertex, vi[2].vertex, _tess);
                o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
                return o;
            }
            
            [UNITY_domain("tri")]
            [UNITY_partitioning("fractional_odd")]
            [UNITY_outputtopology("triangle_cw")]
            [UNITY_patchconstantfunc("HS_PCF")]
            [UNITY_outputcontrolpoints(3)]
            vertex_t HS (InputPatch<vertex_t,3> v, uint id : SV_OutputControlPointID) 
            {
                return v[id];
            }
            ENDCG
        }
    }
}