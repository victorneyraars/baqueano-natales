/// URL de autorización OAuth generada por el backend.
class OAuthUrl {
  const OAuthUrl({required this.url, required this.state});

  final String url;
  final String state;

  factory OAuthUrl.fromJson(Map<String, dynamic> json) {
    return OAuthUrl(url: json['url'] as String, state: json['state'] as String);
  }
}
