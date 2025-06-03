//
//  Generated code. Do not modify.
//  source: sharethem.proto
//
// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class GetSharedFilesRsp extends $pb.GeneratedMessage {
  factory GetSharedFilesRsp({
    $core.Iterable<SharedFile>? files,
  }) {
    final result = create();
    if (files != null) result.files.addAll(files);
    return result;
  }

  GetSharedFilesRsp._();

  factory GetSharedFilesRsp.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(data, registry);
  factory GetSharedFilesRsp.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetSharedFilesRsp', createEmptyInstance: create)
    ..pc<SharedFile>(1, _omitFieldNames ? '' : 'files', $pb.PbFieldType.PM, subBuilder: SharedFile.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSharedFilesRsp clone() => GetSharedFilesRsp()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSharedFilesRsp copyWith(void Function(GetSharedFilesRsp) updates) => super.copyWith((message) => updates(message as GetSharedFilesRsp)) as GetSharedFilesRsp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSharedFilesRsp create() => GetSharedFilesRsp._();
  @$core.override
  GetSharedFilesRsp createEmptyInstance() => create();
  static $pb.PbList<GetSharedFilesRsp> createRepeated() => $pb.PbList<GetSharedFilesRsp>();
  @$core.pragma('dart2js:noInline')
  static GetSharedFilesRsp getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetSharedFilesRsp>(create);
  static GetSharedFilesRsp? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SharedFile> get files => $_getList(0);
}

class SharedFile extends $pb.GeneratedMessage {
  factory SharedFile({
    $core.String? fileName,
    $core.int? fileSize,
    $core.int? fileCrc,
  }) {
    final result = create();
    if (fileName != null) result.fileName = fileName;
    if (fileSize != null) result.fileSize = fileSize;
    if (fileCrc != null) result.fileCrc = fileCrc;
    return result;
  }

  SharedFile._();

  factory SharedFile.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(data, registry);
  factory SharedFile.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SharedFile', createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'fileName')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'fileSize', $pb.PbFieldType.OU3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'fileCrc', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SharedFile clone() => SharedFile()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SharedFile copyWith(void Function(SharedFile) updates) => super.copyWith((message) => updates(message as SharedFile)) as SharedFile;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SharedFile create() => SharedFile._();
  @$core.override
  SharedFile createEmptyInstance() => create();
  static $pb.PbList<SharedFile> createRepeated() => $pb.PbList<SharedFile>();
  @$core.pragma('dart2js:noInline')
  static SharedFile getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SharedFile>(create);
  static SharedFile? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get fileName => $_getSZ(0);
  @$pb.TagNumber(1)
  set fileName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFileName() => $_has(0);
  @$pb.TagNumber(1)
  void clearFileName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get fileSize => $_getIZ(1);
  @$pb.TagNumber(2)
  set fileSize($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFileSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearFileSize() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get fileCrc => $_getIZ(2);
  @$pb.TagNumber(3)
  set fileCrc($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFileCrc() => $_has(2);
  @$pb.TagNumber(3)
  void clearFileCrc() => $_clearField(3);
}


const $core.bool _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
