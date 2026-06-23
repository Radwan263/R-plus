class ScrapingRule {
  final String domainPattern; // Regex pattern to match target domains (e.g., ".*youtube\.com.*")
  final String javascriptCode; // The JavaScript code to be injected
  final int version; // Version of the scraping rule
  final bool isActive; // Whether the rule is currently active
  final List<String> triggerEvents; // Events that trigger injection (e.g., ["onLoadStop", "onXhrComplete"])

  ScrapingRule({
    required this.domainPattern,
    required this.javascriptCode,
    required this.version,
    this.isActive = true,
    this.triggerEvents = const ["onLoadStop"],
  });

  factory ScrapingRule.fromJson(Map<String, dynamic> json) => ScrapingRule(
        domainPattern: json["domainPattern"],
        javascriptCode: json["javascriptCode"],
        version: json["version"],
        isActive: json["isActive"] ?? true,
        triggerEvents: List<String>.from(json["triggerEvents"] ?? ["onLoadStop"]),
      );

  Map<String, dynamic> toJson() => {
        "domainPattern": domainPattern,
        "javascriptCode": javascriptCode,
        "version": version,
        "isActive": isActive,
        "triggerEvents": triggerEvents,
      };
}
