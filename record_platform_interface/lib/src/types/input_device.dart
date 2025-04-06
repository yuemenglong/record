class InputDevice {
  /// The ID used to select the device on the platform.
  final String id;

  /// The label text representation.
  final String label;

  const InputDevice({
    required this.id,
    required this.label,
  });

  factory InputDevice.fromMap(Map map) => InputDevice(
        id: map['id'],
        label: map['label'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
      };

  @override
  String toString() {
    return '''
      id: $id
      label: $label
      ''';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is InputDevice && other.id == id && other.label == label;
  }

  @override
  int get hashCode => id.hashCode ^ label.hashCode;
}
