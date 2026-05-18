import { describe, it, expect } from '@ohos/hypium';
import {
  AI_TASK_CHAT,
  AI_TASK_GENERATE_FULL_PLAN,
  createAiChatMessage,
  deserializeAiConversationHistory,
  serializeAiConversationHistory
} from '../main/ets/models/AiAssistant';
import { UserProfile } from '../main/ets/models/UserProfile';
import { inferAiAssistantTaskFromPrompt, parseAssistantPayload } from '../main/ets/utils/AiAssistantHelper';

function createProfile(): UserProfile {
  return {
    nickname: 'Julia',
    heightCm: '168',
    weightKg: '58',
    age: '27',
    gender: '女'
  };
}

export default function aiAssistantHelperTest() {
  describe('aiAssistantHelperTest', () => {
    it('inferAiAssistantTaskFromPrompt recognizes full plan intent', 0, () => {
      let task = inferAiAssistantTaskFromPrompt('请帮我制定接下来一周的训练和饮食计划');
      expect(task).assertEqual(AI_TASK_GENERATE_FULL_PLAN);
    });

    it('inferAiAssistantTaskFromPrompt keeps plain chat as chat', 0, () => {
      let task = inferAiAssistantTaskFromPrompt('今天为什么感觉训练后很累？');
      expect(task).assertEqual(AI_TASK_CHAT);
    });

    it('parseAssistantPayload extracts structured plan from mixed text', 0, () => {
      let response = parseAssistantPayload(
        '下面是重新生成后的安排：\n```json\n{"reply":"已按你的要求重新生成训练计划","plans":[{"date":"2026-04-27","title":"晨跑","summary":"轻松跑 30 分钟","notes":"保持轻松配速","exerciseId":"running","customName":"","customMode":"duration","customIntensity":"moderate","durationMinutes":"30","distanceKm":"4","paceMinutes":"7","speedKmH":"0","count":"0","cadencePerMinute":"0","sets":"0","workSeconds":"0","restSeconds":"0"}],"foodPlans":[]}\n```\n如果还想调整，我可以继续改。',
        createProfile()
      );

      expect(response.parseSucceeded).assertTrue();
      expect(response.reply).assertEqual('已按你的要求重新生成训练计划');
      expect(response.plans.length).assertEqual(1);
      expect(response.plans[0].title).assertEqual('晨跑');
    });

    it('parseAssistantPayload does not expose malformed json as reply', 0, () => {
      let response = parseAssistantPayload(
        '{"reply":"重新生成","plans":[{"date":"2026-04-27","title":"晨跑"}',
        createProfile()
      );

      expect(response.parseSucceeded).assertFalse();
      expect(response.reply).assertEqual('');
      expect(response.plans.length).assertEqual(0);
    });

    it('conversation history keeps generated drafts on messages', 0, () => {
      let message = createAiChatMessage('assistant', '这是本次计划');
      message.generatedPlans = [{
        id: 'plan-1',
        date: '2026-04-27',
        title: '晨跑',
        summary: '轻松跑 30 分钟',
        notes: '',
        draftText: 'running',
        accentColor: '#0F6BFF',
        imported: false
      }];

      let historyText = serializeAiConversationHistory([{
        id: 'conv-1',
        title: '计划',
        createdAt: 1,
        updatedAt: 2,
        messages: [message]
      }]);
      let restoredHistory = deserializeAiConversationHistory(historyText);

      expect(restoredHistory.length).assertEqual(1);
      expect(restoredHistory[0].messages.length).assertEqual(1);
      expect(restoredHistory[0].messages[0].generatedPlans.length).assertEqual(1);
      expect(restoredHistory[0].messages[0].generatedPlans[0].title).assertEqual('晨跑');
    });
  });
}
