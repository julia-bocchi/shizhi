import { describe, it, expect } from '@ohos/hypium';
import { FoodOption } from '../main/ets/models/FoodOption';
import { SavedCustomWorkout } from '../main/ets/models/ExerciseOption';
import {
  buildDefaultCustomFoodImage,
  createLocalCustomFoodOptionId,
  upsertCustomFoodOptionByIdentity
} from '../main/ets/utils/FoodHelper';
import {
  createLocalSavedCustomWorkoutId,
  upsertSavedCustomWorkoutByIdentity
} from '../main/ets/utils/ExerciseHelper';
import { normalizeUniqueName } from '../main/ets/utils/IdentityHelper';

function createFoodOption(id: string, name: string, calories: number): FoodOption {
  return {
    id: id,
    name: name,
    description: 'test food',
    calories: calories,
    serving: '1 份',
    mealSuggestion: '早餐',
    image: '',
    accentColor: '#F59E0B'
  };
}

function createSavedWorkout(id: string, name: string, durationMinutes: string): SavedCustomWorkout {
  return {
    id: id,
    name: name,
    mode: 'duration',
    intensity: 'moderate',
    durationMinutes: durationMinutes,
    distanceKm: '0',
    paceMinutes: '0',
    speedKmH: '0',
    count: '0',
    cadencePerMinute: '0',
    sets: '0',
    workSeconds: '0',
    restSeconds: '0'
  };
}

export default function identityHelperTest() {
  describe('identityHelperTest', () => {
    it('normalizeUniqueName trims, collapses spaces and lowercases english', 0, () => {
      expect(normalizeUniqueName('  Jump   Rope  ')).assertEqual('jump rope');
    });

    it('createLocalCustomFoodOptionId keeps name-stable id', 0, () => {
      expect(createLocalCustomFoodOptionId('鸡胸 肉卷')).assertEqual(createLocalCustomFoodOptionId(' 鸡胸   肉卷 '));
    });

    it('buildDefaultCustomFoodImage falls back to meal placeholder token', 0, () => {
      expect(buildDefaultCustomFoodImage('dinner')).assertEqual('builtin:meal:dinner');
      expect(buildDefaultCustomFoodImage('')).assertEqual('builtin:meal:breakfast');
    });

    it('upsertCustomFoodOptionByIdentity updates existing option instead of creating duplicate', 0, () => {
      let currentOptions: FoodOption[] = [
        createFoodOption('custom-food-1', 'Chicken Wrap', 280)
      ];
      let result = upsertCustomFoodOptionByIdentity(currentOptions, createFoodOption('local-food-option-chicken-wrap', ' chicken   wrap ', 360));

      expect(result.options.length).assertEqual(1);
      expect(result.option.id).assertEqual('custom-food-1');
      expect(result.option.calories).assertEqual(360);
      expect(result.hasUpdated).assertEqual(true);
    });

    it('upsertSavedCustomWorkoutByIdentity updates existing template instead of creating duplicate', 0, () => {
      let currentItems: SavedCustomWorkout[] = [
        createSavedWorkout('template-1', 'Jump Rope', '20')
      ];
      let result = upsertSavedCustomWorkoutByIdentity(currentItems, createSavedWorkout(
        createLocalSavedCustomWorkoutId(' jump   rope '),
        ' jump   rope ',
        '30'
      ));

      expect(result.savedWorkouts.length).assertEqual(1);
      expect(result.workout.id).assertEqual('template-1');
      expect(result.workout.durationMinutes).assertEqual('30');
      expect(result.hasUpdated).assertEqual(true);
    });
  });
}
