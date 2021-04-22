Shader "Unlit/10.3refraction"
{
    Properties{
        _Color("Color Tint",Color) = (1,1,1,1)
        _RefractColor("Refract Color",Color) = (1,1,1,1)
        _RefractAmount("Refract Amount",Range(0,1)) = 1
        _RefractRatio("Refract Radio",Range(0.1,1)) = 0.5
        //用该属性得到不同介质的透射比，
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
                float3 worldRefr :TEXCOORD2;
                fixed3 worldViewDir :TEXCOORD3;
                SHADOW_COORDS(4)
            };

            //顶点着色器
            v2f vert(a2v v){
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex).xyz;
                o.worldViewDir = UnityWorldSpaceViewDir(o.worldPos);
                o.worldRefr = refract( -normalize(o.worldViewDir),normalize( o.worldNormal),_RefractRatio);
                //CG refract:计算折射方向。它的第一参数即为入射光线的方向，它必须是归一化后的矢量
                //第二个参数是表面法线，法线方向同样需要是归一化后的；
                //第三个参数是光在不同介质的透射比，
                //它的返回值就是计算而得的折射方向，它的模则等于入射光线的模。
                TRANSFER_SHADOW(o);
                return o;
            }
            //片元着色器，进行计算折射光，diffuse ambient 
            fixed4 frag(v2f i):SV_TARGET{
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 worldViewDir = normalize(i.worldViewDir);
                //fixed worldRefract = refract(-worldViewDir,worldNormal,_RefractRatio);

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                fixed3 diffuse = _LightColor0.rgb * _Color.rgb * max(0,dot(worldNormal,worldLightDir));
                fixed3 refraction = texCUBE(_Cubemap,i.worldRefr).rgb * _RefractColor.rgb;
                ////利用折射方向来对立方体纹理采样：

                UNITY_LIGHT_ATTENUATION(atten,i,i.worldPos);

                return fixed4 ( ambient + lerp(diffuse, refraction, _RefractAmount) * atten, 1.0) ;
            }ENDCG
        }
    }FallBack "Reflective/VertexLit"
}