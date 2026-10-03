class Category{
	final int? categoryId;
	final String name;
	final String type;
	final String? icon;
	final bool isDefault;
	final bool isDeleted;
	final DateTime createdAt;
	final DateTime updatedAt;
	
Category({
	this.categoryId,
	required this.name,
	required this.type,
	this.icon,
	required this.isDefault,
	required this.isDeleted,
	required this.createdAt,
	required this.updatedAt,
	});
}