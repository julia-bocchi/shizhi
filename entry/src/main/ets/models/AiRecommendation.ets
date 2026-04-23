export interface AiRecommendationItem {
  id: string;
  score: number;
  reason: string;
}

export interface AiRecommendationCache {
  updatedAt: string;
  reply: string;
  items: AiRecommendationItem[];
}

export interface RecommendationFoodCandidate {
  id: string;
  name: string;
  description: string;
  mealSuggestion: string;
  calories: number;
  serving: string;
}

export interface RecommendationExerciseCandidate {
  id: string;
  name: string;
  description: string;
  category: string;
}

export interface AiRecommendationResponse {
  reply: string;
  foodRankings: AiRecommendationItem[];
  exerciseRankings: AiRecommendationItem[];
}
