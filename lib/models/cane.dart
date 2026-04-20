class Cane {
  String id;
  String nome;
  String razza;
  String microchip;

  Cane({
    required this.id,
    required this.nome,
    required this.razza,
    required this.microchip,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'razza': razza,
        'microchip': microchip,
      };

  factory Cane.fromJson(Map<String, dynamic> json) => Cane(
        id: json['id'],
        nome: json['nome'],
        razza: json['razza'],
        microchip: json['microchip'],
      );
}