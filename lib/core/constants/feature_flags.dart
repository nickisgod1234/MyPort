/// หน้าที่เปิดใช้งานจริง — หน้าอื่นแสดงป้าย "ช่วงทดลอง"
class FeatureFlags {
  static const activeRoutes = <String>{
    'dca',
  };

  static bool isTrial(String route) => !activeRoutes.contains(route);
}
