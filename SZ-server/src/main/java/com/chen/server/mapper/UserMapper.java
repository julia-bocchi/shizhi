package com.chen.server.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.chen.server.domain.entity.User;
import lombok.Data;
import org.springframework.stereotype.Service;

@Service
public interface UserMapper extends BaseMapper<User> {
}
