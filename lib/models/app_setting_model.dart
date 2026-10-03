class AppSetting{
	final int? settingId;
	final String key;
	final String value;
	final DateTime updatedAt;
	
AppSetting({
	this.settingId,
	required this.key,
	required this.value,
	required this.updatedAt,
	});
}