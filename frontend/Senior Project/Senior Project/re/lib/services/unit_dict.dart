class UnitDict {
  static String text(String unit, bool isThai) {
    final u = unit.trim().toLowerCase();
    if (!isThai) return u;

    switch (u) {
      case 'kg':
        return 'กก.';
      case 'g':
        return 'กรัม';
      case 'piece':
        return 'ชิ้น';
      case 'liter':
        return 'ลิตร';
      default:
        return unit; // ถ้าไม่รู้จักก็แสดง raw
    }
  }
}
