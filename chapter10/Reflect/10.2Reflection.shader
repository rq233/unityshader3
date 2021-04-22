Shader "Unlit/10.2Reflection"
{
    Properties{
        _Color("Color Tint",Color) = (1,1,1,1)
        _ReflectColor("Reflection Color",Color) = (1,1,1,1)
        _ReflectAmount("Reflect Amount",Range(0,1)) = 0.5
        //_ReflectAmount 用于控制这个材质的反射程度
        _Cubemap("Reflection Cubemap",Cube) = "_Skybox"{}
        //_Cubemap 用于模拟反射的环境映射纹理
    }

    SubShader{
        Tags{"RenderType" = "Opaque" "Queue" = "Geometry"}

        pass{
            Tags {"LightMode" = "ForwardBase"}
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            //保证我们在 Shader 中使用光照衰减等光照变量可以被正确赋值。
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            fixed4 _Color;
            fixed4 _ReflectColor;
            fixed _ReflectAmount;
            samplerCUBE _Cubemap;

            struct a2v{
                fixed4 vertex :POSITION;
                fixed3 normal :NORMAL;
            };
            struct v2f{
                float4 pos :SV_POSITION;
                float3 worldNormal :TEXCOORD0;
                fixed3 worldPos :TEXCOORD1;
                fixed3 worldViewDir :TEXCOORD2;
                fixed3 worldRefl :TEXCOORD3;
                SHADOW_COORDS(4)
            };

            //定义顶点着色器
            //顶点着色器里面要干啥 处理输入 准备给片元输出
            v2f vert(a2v v){
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);                 //为了得到裁剪空间的齐次坐标
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex).xyz;
                //mul函数 是表示矩阵M和向量V进行点乘，得到一个向量Z，这个向量Z就是对向量V进行矩阵变换后得到的值
                o.worldViewDir = UnityWorldSpaceViewDir(o.worldPos);
                o.worldRefl= reflect(-o.worldViewDir,o.worldNormal);
                //reflect 函数计算定点反射方向
                ///为啥是负？原因：可以计算视角方向关于顶点法线的反射方向来求得入射光线的方向。
                TRANSFER_SHADOW(o);
                return o;
            }

            //出于性能方面的考虑，我们选择在顶点着色器中计算反射方向。也可以在片元着色器中计算的，而且效果还要好一点
            //计算片元着色器 diffuse ambient specular reflection reflection和s相乘 采样反射天空
            fixed4 frag(v2f i):SV_TARGET{
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldViewDir = normalize(i.worldViewDir);
                float3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                fixed3 diffuse = _LightColor0.rgb * _Color.rgb * max(0,dot(worldNormal,worldLightDir));
                fixed3 reflection = texCUBE(_Cubemap,i.worldRefl).rgb * _ReflectColor.rgb;
                //利用反射方向来对立方体纹理采样：
                //reference 参考
                //没有对worldrefl归一化     因为用于采样的参数仅仅是作为方向变量传递给texCUBE 函数的 因此我们没有必要进行一次归一化的操作。
                //归一化处理：数据的标准化（normalization）是将数据按比例缩放，使之落入一个小的特定区间。
                //在某些比较和评价的指标处理中经常会用到，去除数据的单位限制，将其转化为无量纲的纯数值，
                //便于不同单位或量级的指标能够进行比较和加权。
                UNITY_LIGHT_ATTENUATION(atten,i,i.worldPos);
                
                fixed3 color = ambient + lerp(diffuse, reflection, _ReflectAmount) * atten;
				
				return fixed4(color, 1.0);
            }
            ENDCG
        }
    }Fallback "Reflective/VertexLit"
}