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
    String id;
    int v;

    Data({
        required this.categoryname,
        required this.id,
        required this.v,
    });

    factory Data.fromJson(Map<String, dynamic> json) => Data(
        categoryname: json["categoryname"],
        id: json["_id"],
        v: json["__v"],
    );

    Map<String, dynamic> toJson() => {
        "categoryname": categoryname,
        "_id": id,
        "__v": v,
    };
}
