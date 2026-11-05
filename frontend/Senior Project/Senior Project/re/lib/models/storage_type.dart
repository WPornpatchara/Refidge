enum StorageType { pantry, fridge, freezer }

extension StorageTypeX on StorageType {
  String key() => toString().split('.').last;

  String label(bool isThai) {
    switch (this) {
      case StorageType.pantry:
        return isThai ? 'อุณหภูมิห้อง' : 'Pantry';
      case StorageType.fridge:
        return isThai ? 'ตู้เย็น' : 'Fridge';
      case StorageType.freezer:
        return isThai ? 'ช่องฟรีซ' : 'Freezer';
    }
  }

  static StorageType fromKey(String? k) {
    switch ((k ?? '').toLowerCase().trim()) {
      case 'fridge':
        return StorageType.fridge;
      case 'freezer':
        return StorageType.freezer;
      case 'pantry':
      default:
        return StorageType.pantry;
    }
  }
}