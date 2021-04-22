Shader "Unlit/10.3.1"
{
    Properties{
        _Color("Color Tint",Color) = (1,1,1,1)
        _RefractColor("Refract Color",Color) = (1,1,1,1)
        _RefractAmount("Refract Amount",Range(0,1)) = 1
        _RefractRatio("Refract Radio",Range(0.1,1)) = 0.5
        _Cubemap("Refract Cubemap",Cube) = "Skybox"{}
    }

    SubShader{
        Tags{ "RenderType"="Opaque" "Queue"="Geometry"}

        pass{
            Tags{ "LightMode"="ForwardBase"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase	
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            fixed4 _Color;
            fixed4 _RefractColor;
            fixed _RefractRatio;
            fixed _RefractAmount;
            samplerCUBE _Cubemap;

            struct a2v{
                float4 vertex :POSITION;
                float3 normal :NORMAL;
            };
            struct v2f{
                float4 pos :SV_POSITION;
                float3 worldNormal :TEXCOORD0;
                float3 worldPos :TEXCOORD1;
                SHADOW_COORDS(2)
            };

            //顶点着色器
            v2f vert(a2v v){
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex).xyz;
                TRANSFER_SHADOW(o);
                return o;
            }
            //片元着色器，进行计算折射光，diffuse ambient 
            fixed4 frag(v2f i):SV_TARGET{
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed worldRefract = refract(-worldViewDir,worldNormal,_RefractRatio);

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                fixed3 diffuse = _LightColor0.rgb * _Color.rgb * max(0,dot(worldNormal,worldLightDir));
                fixed3 refraction = texCUBE(_Cubemap,worldRefract).rgb * _RefractColor.rgb;

                UNITY_LIGHT_ATTENUATION(atten,i,i.worldPos);

                return fixed4 ( ambient + lerp(diffuse, refraction, _RefractAmount) * atten, 1.0) ;
            }ENDCG
        }
    }FallBack "Reflective/VertexLit"
}