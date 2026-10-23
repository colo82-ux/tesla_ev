/// 차계부 지출 내역 모델 (`expense_logs` 테이블)
class ExpenseLog {
  static const List<String> categories = [
    '충전비',
    '보험료',
    '세차/정비',
    '하이패스/주차',
    '용품/튜닝',
  ];

  final int? id;
  final DateTime date;
  final String category; // '충전비' | '보험료' | '세차/정비' | '하이패스/주차' | '용품/튜닝'
  final int amountKrw;
  final String memo;

  const ExpenseLog({
    this.id,
    required this.date,
    required this.category,
    required this.amountKrw,
    required this.memo,
  });

  ExpenseLog copyWith({
    int? id,
    DateTime? date,
    String? category,
    int? amountKrw,
    String? memo,
  }) {
    return ExpenseLog(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      amountKrw: amountKrw ?? this.amountKrw,
      memo: memo ?? this.memo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date.toIso8601String(),
      'category': category,
      'amount_krw': amountKrw,
      'memo': memo,
    };
  }

  factory ExpenseLog.fromMap(Map<String, dynamic> map) {
    return ExpenseLog(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      category: (map['category'] as String?) ?? '기타',
      amountKrw: (map['amount_krw'] as num).toInt(),
      memo: (map['memo'] as String?) ?? '',
    );
  }
}
