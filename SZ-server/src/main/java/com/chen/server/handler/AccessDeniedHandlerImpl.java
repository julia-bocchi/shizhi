package com.chen.server.handler;




import cn.hutool.json.JSONUtil;
import cn.hutool.json.ObjectMapper;
import com.chen.server.domain.ResponseResult;
import com.chen.server.enums.AppHttpCodeEnum;

import com.chen.server.utils.WebUtils;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;
import java.io.IOException;

@Component
public class AccessDeniedHandlerImpl implements AccessDeniedHandler {

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response,
                      AccessDeniedException accessDeniedException) throws IOException, ServletException {
        ResponseResult result = ResponseResult.errorResult(AppHttpCodeEnum.NO_OPERATOR_AUTH);

        String json = JSONUtil.toJsonStr(result);
        WebUtils.renderString(response, json);
    }
}
