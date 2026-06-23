abstract final class ApiConstants {
  static const baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://bus-ticketing-backend-u0e3.onrender.com',
  );
}
