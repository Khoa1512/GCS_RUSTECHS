/// Token response DTO
class TokenResponseDTO {
  final String value;
  final String expiredAt;

  TokenResponseDTO({required this.value, required this.expiredAt});

  factory TokenResponseDTO.fromJson(Map<String, dynamic> json) {
    return TokenResponseDTO(
      value: json['value'] as String,
      expiredAt: json['expiredAt'] as String,
    );
  }
}
