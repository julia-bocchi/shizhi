package com.chen.server.controller;

import com.chen.server.domain.ResponseResult;
import com.chen.server.domain.Vo.WorkoutTemplateResponse;
import com.chen.server.domain.dto.WorkoutTemplateRequest;
import com.chen.server.service.WorkoutTemplateService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/workout-templates")
public class WorkoutTemplateController {

    @Autowired
    private WorkoutTemplateService workoutTemplateService;

    /**
     * 查询模板列表
     * GET /api/v1/workout-templates
     */
    @GetMapping
    public ResponseResult queryTemplates() {
        Long userId = getCurrentUserId();
        List<WorkoutTemplateResponse> templates = workoutTemplateService.queryTemplates(userId);
        return ResponseResult.okResult(templates);
    }

    /**
     * 新增模板
     * POST /api/v1/workout-templates
     * 
     * 注意：如果同一用户下已存在同名模板，会抛出异常
     * 前端可以在捕获异常后，选择调用更新接口或提示用户
     */
    @PostMapping
    public ResponseResult createTemplate(@RequestBody WorkoutTemplateRequest request) {
        Long userId = getCurrentUserId();
        
        try {
            WorkoutTemplateResponse response = workoutTemplateService.createTemplate(userId, request);
            return ResponseResult.okResult(response);
        } catch (IllegalArgumentException e) {
            // 如果已存在同名模板，返回提示信息
            // 前端可以根据这个提示，询问用户是否要覆盖或修改名称
            return ResponseResult.errorResult(400, e.getMessage());
        }
    }

    /**
     * 更新模板
     * PUT /api/v1/workout-templates/{templateId}
     * 
     * 说明：
     * - 前端在保存模板时，如果"当前编辑的模板ID相同"或"模板名称相同"，会视为更新
     * - 这里提供明确的更新接口，通过templateId定位要更新的模板
     */
    @PutMapping("/{templateId}")
    public ResponseResult updateTemplate(@PathVariable String templateId, 
                                        @RequestBody WorkoutTemplateRequest request) {
        Long userId = getCurrentUserId();
        
        try {
            WorkoutTemplateResponse response = workoutTemplateService.updateTemplate(userId, templateId, request);
            return ResponseResult.okResult(response);
        } catch (IllegalArgumentException e) {
            return ResponseResult.errorResult(400, e.getMessage());
        }
    }

    /**
     * 删除模板
     * DELETE /api/v1/workout-templates/{templateId}
     */
    @DeleteMapping("/{templateId}")
    public ResponseResult deleteTemplate(@PathVariable String templateId) {
        Long userId = getCurrentUserId();
        Boolean result = workoutTemplateService.deleteTemplate(userId, templateId);
        return ResponseResult.okResult(result);
    }

    private Long getCurrentUserId() {
        return 1L;
    }
}