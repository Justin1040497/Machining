enum TaskCompletionSound {
  none('none'),
  cleanSuccess('clean_success'),
  mechanicalKey('mechanical_key'),
  originalSoftA('original_soft_a'),
  originalSoftB('original_soft_b'),
  servoConfirm('servo_confirm');

  const TaskCompletionSound(this.id);

  final String id;

  static TaskCompletionSound fromId(String? id) {
    for (final sound in values) {
      if (sound.id == id) {
        return sound;
      }
    }

    return TaskCompletionSound.none;
  }
}
