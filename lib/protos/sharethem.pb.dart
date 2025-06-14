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

class SharedFileContentNotify extends $pb.GeneratedMessage {
  factory SharedFileContentNotify({
    SharedFile? file,
    $core.List<$core.int>? content,
  }) {
    final result = create();
    if (file != null) result.file = file;
    if (content != null) result.content = content;
    return result;
  }

  SharedFileContentNotify._();

  factory SharedFileContentNotify.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(data, registry);
  factory SharedFileContentNotify.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SharedFileContentNotify', createEmptyInstance: create)
    ..aOM<SharedFile>(1, _omitFieldNames ? '' : 'file', subBuilder: SharedFile.create)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'content', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SharedFileContentNotify clone() => SharedFileContentNotify()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SharedFileContentNotify copyWith(void Function(SharedFileContentNotify) updates) => super.copyWith((message) => updates(message as SharedFileContentNotify)) as SharedFileContentNotify;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SharedFileContentNotify create() => SharedFileContentNotify._();
  @$core.override
  SharedFileContentNotify createEmptyInstance() => create();
  static $pb.PbList<SharedFileContentNotify> createRepeated() => $pb.PbList<SharedFileContentNotify>();
  @$core.pragma('dart2js:noInline')
  static SharedFileContentNotify getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SharedFileContentNotify>(create);
  static SharedFileContentNotify? _defaultInstance;

  @$pb.TagNumber(1)
  SharedFile get file => $_getN(0);
  @$pb.TagNumber(1)
  set file(SharedFile value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasFile() => $_has(0);
  @$pb.TagNumber(1)
  void clearFile() => $_clearField(1);
  @$pb.TagNumber(1)
  SharedFile ensureFile() => $_ensure(0);

  @$pb.TagNumber(4)
  $core.List<$core.int> get content => $_getN(1);
  @$pb.TagNumber(4)
  set content($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(4)
  $core.bool hasContent() => $_has(1);
  @$pb.TagNumber(4)
  void clearContent() => $_clearField(4);
}

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
    $core.String? senderId,
    $core.String? senderName,
  }) {
    final result = create();
    if (fileName != null) result.fileName = fileName;
    if (fileSize != null) result.fileSize = fileSize;
    if (fileCrc != null) result.fileCrc = fileCrc;
    if (senderId != null) result.senderId = senderId;
    if (senderName != null) result.senderName = senderName;
    return result;
  }

  SharedFile._();

  factory SharedFile.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(data, registry);
  factory SharedFile.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SharedFile', createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'fileName')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'fileSize', $pb.PbFieldType.OU3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'fileCrc', $pb.PbFieldType.OU3)
    ..aOS(4, _omitFieldNames ? '' : 'senderId')
    ..aOS(5, _omitFieldNames ? '' : 'senderName')
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

  /// ADD THESE TWO NEW FIELDS
  @$pb.TagNumber(4)
  $core.String get senderId => $_getSZ(3);
  @$pb.TagNumber(4)
  set senderId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSenderId() => $_has(3);
  @$pb.TagNumber(4)
  void clearSenderId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get senderName => $_getSZ(4);
  @$pb.TagNumber(5)
  set senderName($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSenderName() => $_has(4);
  @$pb.TagNumber(5)
  void clearSenderName() => $_clearField(5);
}


const $core.bool _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
