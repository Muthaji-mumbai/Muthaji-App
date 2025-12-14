  // To parse this JSON data, do
//
//     final categoryResponse = categoryResponseFromJson(jsonString);

import 'dart:convert';

CategoryResponse categoryResponseFromJson(String str) => CategoryResponse.fromJson(json.decode(str));

String categoryResponseToJson(CategoryResponse data) => json.encode(data.toJson());

class CategoryResponse {
    bool success;
    Data data;
    String message;

    CategoryResponse({
        required this.success,
        required this.data,
        required this.message,
    });

    factory CategoryResponse.fromJson(Map<String, dynamic> json) => CategoryResponse(
        success: json["success"],
        data: Data.fromJson(json["data"]),
        message: json["message"],
    );

    Map<String, dynamic> toJson() => {
        "success": success,
        "data": data.toJson(),
        "message": message,
    };
}

class Data {
    String categoryname;
    List<String> size;
    List<String> unit;
    String id;
    int v;

    Data({
        required this.categoryname,
        required this.size,
        required this.unit,
        required this.id,
        required this.v,
    });

    factory Data.fromJson(Map<String, dynamic> json) => Data(
        categoryname: json["categoryname"],
        size: json["size"] == null
            ? <String>[]
            : List<String>.from((json["size"] as List).map((x) => x.toString())),
        unit: json["unit"] == null
            ? <String>[]
            : (json["unit"] is List
                ? List<String>.from((json["unit"] as List).map((x) => x.toString()))
                : <String>[json["unit"].toString()]),
        id: json["_id"],
        v: json["__v"] ?? 0,
    );

    Map<String, dynamic> toJson() => {
        "categoryname": categoryname,
        "size": List<dynamic>.from(size.map((x) => x)),
        "unit": List<dynamic>.from(unit.map((x) => x)),
        "_id": id,
        "__v": v,
    };
}
