package com.chen.server.service;

import com.chen.server.domain.Vo.WorkoutTemplateResponse;
import com.chen.server.domain.dto.WorkoutTemplateRequest;
import org.springframework.stereotype.Service;

import java.util.List;
@Service
public interface WorkoutTemplateService {

    /**
     * 查询用户的所有训练模板
     */
    List<WorkoutTemplateResponse> queryTemplates(Long userId);

    /**
     * 创建新的训练模板
     * 如果同一用户下已存在同名模板，则返回null或抛出异常
     */
    WorkoutTemplateResponse createTemplate(Long userId, WorkoutTemplateRequest request);

    /**
     * 更新训练模板
     * 支持根据templateId更新，同时检查名称唯一性
     */
    WorkoutTemplateResponse updateTemplate(Long userId, String templateId, WorkoutTemplateRequest request);

    /**
     * 删除训练模板
     */
    Boolean deleteTemplate(Long userId, String templateId);
}