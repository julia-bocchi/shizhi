package com.chen.server.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.chen.server.domain.Vo.WorkoutPlanListResponse;
import com.chen.server.domain.Vo.WorkoutPlanResponse;
import com.chen.server.domain.dto.WorkoutPlanQueryRequest;
import com.chen.server.domain.dto.WorkoutPlanRequest;
import com.chen.server.domain.entity.WorkoutPlan;
import com.chen.server.mapper.WorkoutPlanMapper;
import com.chen.server.service.WorkoutPlanService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class WorkoutPlanServiceImpl implements WorkoutPlanService {

    @Autowired
    private WorkoutPlanMapper workoutPlanMapper;

    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd");

    @Override
    public WorkoutPlanListResponse queryWorkoutPlans(Long userId, WorkoutPlanQueryRequest queryRequest) {
        LambdaQueryWrapper<WorkoutPlan> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WorkoutPlan::getUserId, userId);

        if (StringUtils.hasText(queryRequest.getStartDate())) {
            LocalDate startDate = LocalDate.parse(queryRequest.getStartDate(), DATE_FORMATTER);
            wrapper.ge(WorkoutPlan::getDate, startDate);
        }

        if (StringUtils.hasText(queryRequest.getEndDate())) {
            LocalDate endDate = LocalDate.parse(queryRequest.getEndDate(), DATE_FORMATTER);
            wrapper.le(WorkoutPlan::getDate, endDate);
        }

        wrapper.orderByAsc(WorkoutPlan::getDate)
               .orderByDesc(WorkoutPlan::getId);

        List<WorkoutPlan> plans = workoutPlanMapper.selectList(wrapper);

        List<WorkoutPlanResponse> responseList = plans.stream()
                .map(plan -> new WorkoutPlanResponse(
                        String.valueOf(plan.getId()),
                        plan.getDate(),
                        plan.getTitle(),
                        plan.getSummary(),
                        plan.getNotes(),
                        plan.getDraftText(),
                        plan.getSavedWorkoutId(),
                        plan.getAccentColor()
                ))
                .collect(Collectors.toList());

        return new WorkoutPlanListResponse(responseList);
    }

    @Override
    public WorkoutPlanResponse createWorkoutPlan(Long userId, WorkoutPlanRequest request) {
        WorkoutPlan plan = new WorkoutPlan();
        plan.setUserId(userId);
        plan.setDate(request.getDate());
        plan.setTitle(request.getTitle());
        plan.setNotes(request.getNotes());
        plan.setDraftText(request.getDraftText());
        plan.setSavedWorkoutId(request.getSavedWorkoutId());

        String summary = generateSummary(request);
        plan.setSummary(summary);

        String accentColor = generateAccentColor(request.getTitle());
        plan.setAccentColor(accentColor);

        workoutPlanMapper.insert(plan);

        return new WorkoutPlanResponse(
                String.valueOf(plan.getId()),
                plan.getDate(),
                plan.getTitle(),
                plan.getSummary(),
                plan.getNotes(),
                plan.getDraftText(),
                plan.getSavedWorkoutId(),
                plan.getAccentColor()
        );
    }

    @Override
    public Boolean deleteWorkoutPlan(Long userId, String planId) {
        LambdaQueryWrapper<WorkoutPlan> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WorkoutPlan::getId, Long.parseLong(planId))
               .eq(WorkoutPlan::getUserId, userId);

        return workoutPlanMapper.delete(wrapper) > 0;
    }

    private String generateSummary(WorkoutPlanRequest request) {
        StringBuilder summary = new StringBuilder();

        if (StringUtils.hasText(request.getDraftText())) {
            try {
                String decoded = java.net.URLDecoder.decode(request.getDraftText(), "UTF-8");
                String[] parts = decoded.split("\\|\\|");
                
                if (parts.length > 0 && StringUtils.hasText(parts[0])) {
                    summary.append(parts[0]);
                }

                if (parts.length > 4 && StringUtils.hasText(parts[4])) {
                    summary.append(" · ").append(parts[4]).append(" 分钟");
                }

                if (parts.length > 5 && StringUtils.hasText(parts[5])) {
                    summary.append(" · ").append(parts[5]).append(" kcal");
                }
            } catch (Exception e) {
                summary.append("训练计划");
            }
        } else {
            summary.append("训练计划");
        }

        return summary.toString();
    }

    private String generateAccentColor(String title) {
        if (!StringUtils.hasText(title)) {
            return "#2F6FED";
        }

        int hash = title.hashCode();
        String[] colors = {
            "#2F6FED", "#FF6B6B", "#4ECDC4", "#45B7D1", 
            "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8"
        };
        
        int index = Math.abs(hash) % colors.length;
        return colors[index];
    }
}