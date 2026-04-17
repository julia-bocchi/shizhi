package com.chen.server.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.chen.server.domain.Vo.WorkoutTemplateResponse;
import com.chen.server.domain.dto.WorkoutTemplateRequest;
import com.chen.server.domain.entity.WorkoutTemplate;
import com.chen.server.mapper.WorkoutTemplateMapper;
import com.chen.server.service.WorkoutTemplateService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class WorkoutTemplateServiceImpl implements WorkoutTemplateService {

    @Autowired
    private WorkoutTemplateMapper workoutTemplateMapper;

    @Override
    public List<WorkoutTemplateResponse> queryTemplates(Long userId) {
        LambdaQueryWrapper<WorkoutTemplate> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WorkoutTemplate::getUserId, userId)
               .orderByDesc(WorkoutTemplate::getId);

        List<WorkoutTemplate> templates = workoutTemplateMapper.selectList(wrapper);

        return templates.stream()
                .map(this::convertToResponse)
                .collect(Collectors.toList());
    }

    @Override
    public WorkoutTemplateResponse createTemplate(Long userId, WorkoutTemplateRequest request) {
        // 校验必填字段：name不能为空
        if (!StringUtils.hasText(request.getName())) {
            throw new IllegalArgumentException("模板名称不能为空");
        }

        // 检查同一用户下是否已存在同名模板
        int count = workoutTemplateMapper.countByName(userId, request.getName());
        if (count > 0) {
            // 前端期望：如果名称相同视为更新，这里可以选择抛出异常让前端处理
            // 或者自动转为更新逻辑。这里选择抛出异常，由Controller层决定如何处理
            throw new IllegalArgumentException("已存在同名模板：" + request.getName());
        }

        WorkoutTemplate template = new WorkoutTemplate();
        template.setUserId(userId);
        template.setName(request.getName());
        template.setMode(request.getMode());
        template.setIntensity(request.getIntensity());
        template.setDurationMinutes(request.getDurationMinutes());
        template.setDistanceKm(request.getDistanceKm());
        template.setPaceMinutes(request.getPaceMinutes());
        template.setSpeedKmH(request.getSpeedKmH());
        template.setCount(request.getCount());
        template.setCadencePerMinute(request.getCadencePerMinute());
        template.setSets(request.getSets());
        template.setWorkSeconds(request.getWorkSeconds());
        template.setRestSeconds(request.getRestSeconds());

        workoutTemplateMapper.insert(template);

        return convertToResponse(template);
    }

    @Override
    public WorkoutTemplateResponse updateTemplate(Long userId, String templateId, WorkoutTemplateRequest request) {
        // 校验必填字段
        if (!StringUtils.hasText(request.getName())) {
            throw new IllegalArgumentException("模板名称不能为空");
        }

        Long id = Long.parseLong(templateId);

        // 查询原模板是否存在且属于当前用户
        WorkoutTemplate existingTemplate = workoutTemplateMapper.selectById(id);
        if (existingTemplate == null || !existingTemplate.getUserId().equals(userId)) {
            throw new IllegalArgumentException("模板不存在或无权限");
        }

        // 检查名称唯一性：排除当前模板ID
        int count = workoutTemplateMapper.countByNameExcludingId(userId, request.getName(), id);
        if (count > 0) {
            throw new IllegalArgumentException("已存在同名模板：" + request.getName());
        }

        // 更新字段
        existingTemplate.setName(request.getName());
        existingTemplate.setMode(request.getMode());
        existingTemplate.setIntensity(request.getIntensity());
        existingTemplate.setDurationMinutes(request.getDurationMinutes());
        existingTemplate.setDistanceKm(request.getDistanceKm());
        existingTemplate.setPaceMinutes(request.getPaceMinutes());
        existingTemplate.setSpeedKmH(request.getSpeedKmH());
        existingTemplate.setCount(request.getCount());
        existingTemplate.setCadencePerMinute(request.getCadencePerMinute());
        existingTemplate.setSets(request.getSets());
        existingTemplate.setWorkSeconds(request.getWorkSeconds());
        existingTemplate.setRestSeconds(request.getRestSeconds());

        workoutTemplateMapper.updateById(existingTemplate);

        return convertToResponse(existingTemplate);
    }

    @Override
    public Boolean deleteTemplate(Long userId, String templateId) {
        Long id = Long.parseLong(templateId);

        // 确保只能删除自己的模板
        LambdaQueryWrapper<WorkoutTemplate> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WorkoutTemplate::getId, id)
               .eq(WorkoutTemplate::getUserId, userId);

        return workoutTemplateMapper.delete(wrapper) > 0;
    }

    /**
     * 将实体转换为响应VO
     */
    private WorkoutTemplateResponse convertToResponse(WorkoutTemplate template) {
        return new WorkoutTemplateResponse(
                String.valueOf(template.getId()),
                template.getName(),
                template.getMode(),
                template.getIntensity(),
                template.getDurationMinutes(),
                template.getDistanceKm(),
                template.getPaceMinutes(),
                template.getSpeedKmH(),
                template.getCount(),
                template.getCadencePerMinute(),
                template.getSets(),
                template.getWorkSeconds(),
                template.getRestSeconds()
        );
    }
}