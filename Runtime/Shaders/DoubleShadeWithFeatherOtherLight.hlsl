float3 UTS_OtherLights(FragInputs input, float3 i_normalDir,
    float3 additionalLightColor, float3 lightDirection, float notDirectional)
{

    /* todo. these should be put into struct */
#ifdef VARYINGS_NEED_POSITION_WS
    float3 V = GetWorldSpaceNormalizeViewDir(input.positionRWS);
#else
    // Unused
    float3 V = float3(1.0, 1.0, 1.0); // Avoid the division by 0
#endif

    float4 Set_UV0 = input.texCoord0;
    float3x3 tangentTransform = input.tangentToWorld;
    //UnpackNormalmapRGorAG(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, texCoords))
    float4 n = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, Set_UV0); // todo. TRANSFORM_TEX
//    float3 _NormalMap_var = UnpackNormalScale(tex2D(_NormalMap, TRANSFORM_TEX(Set_UV0, _NormalMap)), _BumpScale);
    float3 _NormalMap_var = UnpackNormalScale(n, _BumpScale);
    float3 normalLocal = _NormalMap_var.rgb;
    float3 normalDirection = normalize(mul(normalLocal, tangentTransform)); // Perturbed normals
 //   float3 i_normalDir = surfaceData.normalWS;
    float3 viewDirection = V;
    float4 _MainTex_var = tex2D(_MainTex, TRANSFORM_TEX(Set_UV0, _MainTex));
    /* end of todo.*/



    //v.2.0.5: 
    float3 addPassLightColor = (0.5 * dot(lerp(i_normalDir, normalDirection, _Is_NormalMapToBase), lightDirection) + 0.5) * additionalLightColor.rgb;
    float  pureIntencity = max(0.001, (0.299 * additionalLightColor.r + 0.587 * additionalLightColor.g + 0.114 * additionalLightColor.b));
    float3 lightColor = max(0, lerp(addPassLightColor, lerp(0, min(addPassLightColor, addPassLightColor / pureIntencity), notDirectional), _Is_Filter_LightColor));
    float3 halfDirection = normalize(viewDirection + lightDirection); // has to be recalced here.
    //v.2.0.5:
    _BaseColor_Step = saturate(_BaseColor_Step + _StepOffset);
    _ShadeColor_Step = saturate(_ShadeColor_Step + _StepOffset);
    //
    //v.2.0.5: If Added lights is directional, set 0 as _LightIntensity
    float _LightIntensity = lerp(0, (0.299 * additionalLightColor.r + 0.587 * additionalLightColor.g + 0.114 * additionalLightColor.b), notDirectional);
    //v.2.0.5: Filtering the high intensity zone of PointLights
    float3 Set_LightColor = lerp(lightColor, lerp(lightColor, min(lightColor, additionalLightColor.rgb * _BaseColor_Step), notDirectional), _Is_Filter_HiCutPointLightColor);
    //
    float3 Set_BaseColor = lerp((_BaseColor.rgb * _MainTex_var.rgb * _LightIntensity), ((_BaseColor.rgb * _MainTex_var.rgb) * Set_LightColor), _Is_LightColor_Base);

#ifdef UTS_LAYER_VISIBILITY
    Set_BaseColor = lerp(Set_BaseColor, _BaseColorMaskColor, _BaseColorOverridden);
    Set_BaseColor *= _BaseColorVisible;
#endif //#ifdef UTS_LAYER_VISIBILITY    //v.2.0.5
    float4 _1st_ShadeMap_var = lerp(tex2D(_1st_ShadeMap, TRANSFORM_TEX(Set_UV0, _1st_ShadeMap)), _MainTex_var, _Use_BaseAs1st);
    float3 Set_1st_ShadeColor = lerp((_1st_ShadeColor.rgb * _1st_ShadeMap_var.rgb * _LightIntensity), ((_1st_ShadeColor.rgb * _1st_ShadeMap_var.rgb) * Set_LightColor), _Is_LightColor_1st_Shade);
#ifdef UTS_LAYER_VISIBILITY
    Set_1st_ShadeColor = lerp(Set_1st_ShadeColor, _FirstShadeMaskColor, _FirstShadeOverridden);
    Set_1st_ShadeColor = lerp(Set_1st_ShadeColor, Set_BaseColor, 1.0f - _FirstShadeVisible);
#endif //#ifdef UTS_LAYER_VISIBILITY    //v.2.0.5
    float4 _2nd_ShadeMap_var = lerp(tex2D(_2nd_ShadeMap, TRANSFORM_TEX(Set_UV0, _2nd_ShadeMap)), _1st_ShadeMap_var, _Use_1stAs2nd);
    float3 Set_2nd_ShadeColor = lerp((_2nd_ShadeColor.rgb * _2nd_ShadeMap_var.rgb * _LightIntensity), ((_2nd_ShadeColor.rgb * _2nd_ShadeMap_var.rgb) * Set_LightColor), _Is_LightColor_2nd_Shade);
    float _HalfLambert_var = 0.5 * dot(lerp(i_normalDir, normalDirection, _Is_NormalMapToBase), lightDirection) + 0.5;
    float4 _Set_2nd_ShadePosition_var = tex2D(_Set_2nd_ShadePosition, TRANSFORM_TEX(Set_UV0, _Set_2nd_ShadePosition));
    float4 _Set_1st_ShadePosition_var = tex2D(_Set_1st_ShadePosition, TRANSFORM_TEX(Set_UV0, _Set_1st_ShadePosition));
    //v.2.0.5:
    float Set_FinalShadowMask = saturate((1.0 + ((lerp(_HalfLambert_var, (_HalfLambert_var * saturate(1.0 + _Tweak_SystemShadowsLevel)), _Set_SystemShadowsToBase) - (_BaseColor_Step - _BaseShade_Feather)) * ((1.0 - _Set_1st_ShadePosition_var.rgb).r - 1.0)) / (_BaseColor_Step - (_BaseColor_Step - _BaseShade_Feather))));

    //Composition: 3 Basic Colors as finalColor
#ifdef UTS_LAYER_VISIBILITY
    Set_2nd_ShadeColor = lerp(Set_2nd_ShadeColor, _SecondShadeMaskColor, _SecondShadeOverridden);
    Set_2nd_ShadeColor = lerp(Set_2nd_ShadeColor, Set_BaseColor, 1.0f - _SecondShadeVisible);
#endif //#ifdef UTS_LAYER_VISIBILITY
    float3 finalColor = lerp(Set_BaseColor, lerp(Set_1st_ShadeColor, Set_2nd_ShadeColor, saturate((1.0 + ((_HalfLambert_var - (_ShadeColor_Step - _1st2nd_Shades_Feather)) * ((1.0 - _Set_2nd_ShadePosition_var.rgb).r - 1.0)) / (_ShadeColor_Step - (_ShadeColor_Step - _1st2nd_Shades_Feather))))), Set_FinalShadowMask); // Final Color

    //v.2.0.6: Add HighColor if _Is_Filter_HiCutPointLightColor is False


    float4 _Set_HighColorMask_var = tex2D(_Set_HighColorMask, TRANSFORM_TEX(Set_UV0, _Set_HighColorMask));
    float _Specular_var = 0.5 * dot(halfDirection, lerp(i_normalDir, normalDirection, _Is_NormalMapToHighColor)) + 0.5; //  Specular                
    float _TweakHighColorMask_var = (saturate((_Set_HighColorMask_var.g + _Tweak_HighColorMaskLevel)) * lerp((1.0 - step(_Specular_var, (1.0 - pow(_HighColor_Power, 5)))), pow(_Specular_var, exp2(lerp(11, 1, _HighColor_Power))), _Is_SpecularToHighColor));
    float4 _HighColor_Tex_var = tex2D(_HighColor_Tex, TRANSFORM_TEX(Set_UV0, _HighColor_Tex));
    float3 _HighColor_var = lerp((_HighColor_Tex_var.rgb * _HighColor.rgb), ((_HighColor_Tex_var.rgb * _HighColor.rgb) * Set_LightColor), _Is_LightColor_HighColor);
#ifdef UTS_LAYER_VISIBILITY
    _HighColor_var *= _TweakHighColorMask_var;
    _HighColor_var *= _HighlightVisible;
    finalColor =
        lerp(saturate(finalColor - _TweakHighColorMask_var), finalColor,
            lerp(_Is_BlendAddToHiColor, 1.0
                , _Is_SpecularToHighColor));
    float3 addColor =
        lerp(_HighColor_var, (_HighColor_var * ((1.0 - Set_FinalShadowMask) + (Set_FinalShadowMask * _TweakHighColorOnShadow)))
            , _Is_UseTweakHighColorOnShadow);
    finalColor += addColor;
    if (any(addColor))
    {
        finalColor = lerp(finalColor, _HighlightMaskColor, _HighlightOverridden);
    }
#else
    _HighColor_var *= _TweakHighColorMask_var;
    finalColor = finalColor + lerp(lerp(_HighColor_var, (_HighColor_var * ((1.0 - Set_FinalShadowMask) + (Set_FinalShadowMask * _TweakHighColorOnShadow))), _Is_UseTweakHighColorOnShadow), float3(0, 0, 0), _Is_Filter_HiCutPointLightColor);
#endif //#ifdef UTS_LAYER_VISIBILITY
    //

    finalColor = saturate(finalColor);

    //    pointLightColor += finalColor;



    return finalColor;
}