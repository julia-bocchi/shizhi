package com.chen.server.handler;



import cn.hutool.json.JSONUtil;
import cn.hutool.json.ObjectMapper;
import com.chen.server.domain.ResponseResult;
import com.chen.server.enums.AppHttpCodeEnum;
import com.chen.server.utils.WebUtils;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;


import java.io.IOException;

@Component
public class AuthenticationEntryPointImpl implements AuthenticationEntryPoint {

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authException) throws IOException, ServletException {
        ResponseResult result = ResponseResult.errorResult(AppHttpCodeEnum.NEED_LOGIN);

        String json = JSONUtil.toJsonStr(result);
        WebUtils.renderString(response, json);
    }
}
