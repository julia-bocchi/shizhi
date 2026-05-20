package com.chen.server.handler;

import com.chen.server.domain.ResponseResult;
import com.chen.server.enums.AppHttpCodeEnum;
import com.chen.server.execption.SystemException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(SystemException.class)
    public ResponseResult<?> systemExceptionHandler(SystemException e) {
        log.error("业务异常: code={}, msg={}", e.getCode(), e.getMsg());
        return ResponseResult.errorResult(e.getCode(), e.getMsg());
    }

    @ExceptionHandler(BadCredentialsException.class)
    public ResponseResult<?> badCredentialsExceptionHandler(BadCredentialsException e) {
        log.error("认证失败: {}", e.getMessage());
        return ResponseResult.errorResult(AppHttpCodeEnum.LOGIN_ERROR);
    }

    @ExceptionHandler(Exception.class)
    public ResponseResult<?> exceptionHandler(Exception e) {
        log.error("系统异常: ", e);
        return ResponseResult.errorResult(AppHttpCodeEnum.SYSTEM_ERROR);
    }
}