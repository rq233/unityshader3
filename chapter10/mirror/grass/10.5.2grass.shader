Shader "Unlit/10.5.2grass"
{
    Properties{
        _Color("Color Tint",Color) = (1,1,1,1)
        _Bump("Bump",2D) = "white"{} 
        //得到法线
        _MainTex("Main Tex",2D) = "white"{}
        //得到表面纹理
        _Cubemap("Reflection Cubemap",Cube) = "Skybox"{}
        //为了是映射环境
        _Distortion("Distortion",Range(2,255)) = 20
        //Distortion：失真  用于控制模拟折射时图像的扭曲程度；
        _RefractAmount("Refract Aount",Range(0,1)) = 1
        //控制折射程度
    }

    SubShader{
        Tags{"Queue" = "Transparent" "RenderType" = "Opaque"}
        //queue:序列 transparent：透明的  opaque：不透明的
        // Queue设置成 Transparent 可以确保该物体渲染时，其他所有不透明物体都已经被渲染到屏幕上了
        //设置 RenderType 则是为了在使用着色器替换(Shader Replacement)时，该物体可以在需要时被正确渲染。这通常发生在我们需要得到摄像机的深度和法线纹理时
        //提问：1。着色器替换是什么？

        GrabPass{"_RefractionTex"}
        //通过关键词 GrabPass 定义了一个抓取屏幕图像的 Pass 。
        //在这个Pass中我们定义一个字符串，该字符串内部的名称决定了抓取得到的屏幕图像将会被存入哪个纹理中。
        pass{
            //Tags{"LightMode" = "ForwardBase"}
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            
            float4 _Color;
            sampler2D _Bump;
            float4 _Bump_ST;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            samplerCUBE _Cubemap;
            fixed _Distortion;
            fixed _RefractAmount;
            sampler2D _RefractionTex;
            //grasspass中，把屏幕图像存储在refractiontex中
            float4 _RefractionTex_TexelSize;
            //我们需要在对屏幕图像的采样坐标进行偏移时使用该变量。
            //_Refraction Tex_ Texe!S ize 可以让我们得到该纹理的纹素大小

            struct a2v{
                float4 vertex :POSITION;
                float3 normal :NORMAL;
                float4 texcoord :TEXCOORD0;
                float4 tangent :TANGENT;
                //它是float4类型，需要用tangent.w 分量来决定切线空间中的第三个坐标轴一副切线的方向性
            };
            //需要计算的量 ambient环境光 diffuse漫反射 specualer镜面反射
            //这里的玻璃材质特性：透明 有着折射效果 会映射环境 映射的物体有种便宜错乱的效果
            //映射-用天空盒子映射 折射-用折射函数 错乱用法线偏移
            //以便对 Cubemap 进行采样,我们这里选择把切线空间转化成世界空间
            //这里我们将空间统一转化世界空间，应为要用cube映射
            //提问：为什么用cube映射要在切线空间
            struct v2f{
                float4 pos :SV_POSITION;
                float4 uv :TEXCOORD0;
                float4 scrPos :TEXCOORD1;
                float4 TtoW1 :TEXCOORD2;
                float4 TtoW2 :TEXCOORD3;
                float4 TtoW3 :TEXCOORD4;
            };
            //顶点着色器计算 计算转换后的矩阵元素 - 需要有法向量 切线向量 副切线向量
            v2f vert(a2v v){
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.scrPos = ComputeGrabScreenPos(o.pos);
                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.texcoord, _Bump);
                //这里的法向量 切线向量 副切线向量不需要输出，只需要计算点坐标，做就用float就行
                float3 worldNormal = UnityObjectToWorldNormal( v.normal);
                float3 worldtangent = UnityObjectToWorldDir(v.tangent.xyz);
                float3 worldBinormal = cross(worldNormal,worldtangent) * v.tangent.w;

                o.TtoW1 = float4( worldtangent.x , worldBinormal.x , worldNormal.x , o.pos.x);
                o.TtoW2 = float4( worldtangent.y , worldBinormal.y , worldNormal.y , o.pos.y);
                o.TtoW3 = float4( worldtangent.z , worldBinormal.z , worldNormal.z , o.pos.z);
                
                //顶点着色器需要输出的坐标
                return o;
            }
            //计算片元着色器
            //计算的包括法线 折射光线 反射的环境采样
            fixed4 frag (v2f i) :SV_TARGET{
                ///计算切线空间中的法线与折射
                fixed3 worldPos = float3( i.TtoW1.w , i.TtoW2.w ,i.TtoW3.w);
                fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
                fixed3 bump = UnpackNormal( tex2D( _Bump, i.uv.zw));
                //将法线转化到世界空间
                bump = normalize(half3( dot(i.TtoW1.xyz,bump) , dot(i.TtoW2.xyz,bump) , dot(i.TtoW3.xyz,bump)));

                //计算切线空间中的法线偏移
                //在这里，选择使用切线空间下法线方向来进行，是因为该空间下的法线可以反映顶点局部空间下的法线方向
                float2 offset = bump.xy *_Distortion * _RefractionTex_TexelSize.xy;
                i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy;
                //对scrPos 透视除法得到真正的屏幕坐标
                
                //计算各种反射
                //再使用屏幕坐标对抓取的屏幕图像_ Refraction Tex 进行采样，得到模拟的折射颜色。
                fixed3 fraColor = tex2D(_RefractionTex,i.scrPos.xy/i.scrPos.w).rgb;
                fixed3 reflDir = reflect(-worldViewDir,bump);
                fixed3 texColor = tex2D(_MainTex,i.uv.xy)*_Color;
                fixed3 reflColor = texCUBE(_Cubemap,reflDir).rgb * texColor.rgb ;
                
                //总色彩
                fixed3 finalcolor = reflColor * (1 - _RefractAmount) + fraColor * _RefractAmount;
                
                return fixed4(finalcolor,1.0);
            }
            ENDCG
        }
    }Fallback "Diffuse"
}
