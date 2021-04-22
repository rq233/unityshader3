Shader "Unlit/10.4Fresnel reflection"
{
    Properties{
        _Color("Color Tint",Color) = (1,1,1,1)
        _FresnelScale("Fresnel Scale",Range(0,1)) = 0.5
        _Cubemap("Reflection Cubemap",Cube) = "Skybox"{}
    }

    SubShader{
        Tags {"RenderType" = "Opaque"  "Queue" = "Geometry"}

        pass{
            Tags{ "LightMode" = "ForwardBase"}
            CGPROGRAM
            #pragma multi_compile_fwdbase 
            //这里要好好记，好几次错了
            #pragma vertex vert
            #pragma fragment frag
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            fixed4 _Color;
            fixed _FresnelScale;
            samplerCUBE _Cubemap;

            struct a2v{
                float4 vertex :POSITION;
                float3 normal :NORMAL;
            };
            ///记住 分号 ！! !

            //因为要在顶点着色器里计算菲涅尔反射光，所以输出结构这里也得做表现
            struct v2f{
                float4 pos :SV_POSITION;
                float3 worldNormal :TEXCOORD0;
                float3 worldPos :TEXCOORD1;
                float3 worldViewDir :TEXCOORD2;
                float3 worldRefl :TEXCOORD3;
                SHADOW_COORDS(4)
            };
            ///记住 分号 ！! !


            //定点着色器 计算反射 给片元着色器准备数据 
            v2f vert(a2v v){
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex).xyz;
                o.worldViewDir = UnityWorldSpaceViewDir(o.worldPos);
                o.worldRefl = reflect(-o.worldViewDir,o.worldNormal);
                //为什么反射不归一化，折射要归一化
                //为什么不是菲涅尔代替反射，而是一起
                TRANSFER_SHADOW(o);
                return o;
            }

            //片元着色器中进行计算
            ///前面的类型一定一定不要写错！
            fixed4 frag(v2f i):SV_TARGET{
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 worldViewDir = normalize(i.worldViewDir);

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                fixed3 diffuse = _LightColor0.rgb * _Color.rgb * max(0,dot(worldNormal,worldLightDir));
                fixed3 reflection = texCUBE(_Cubemap,i.worldRefl).rgb;
                fixed fresnel = _FresnelScale + (1 - _FresnelScale )*pow(1-dot(worldViewDir,worldNormal),5); 
                
                UNITY_LIGHT_ATTENUATION(atten,i,i.worldPos);

                fixed3 color = ambient + lerp(diffuse,reflection,saturate(fresnel))*atten;
                //之前错误在函数内符号
                //lerp(a, b, w);a与b为同类形，即都是float或者float2之类的，那lerp函数返回的结果也是与ab同类型的值。
                //w是比重，在0到1之间当w为0时返回a，为1时返回b，在01之间时，以比重w将ab进行线性插值计算。
                return fixed4(color,1.0);
            }ENDCG
        }
    }Fallback "Reflective/VertexLit"
}