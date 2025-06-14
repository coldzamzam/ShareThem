//
//  Generated code. Do not modify.
//  source: packet.proto
//
// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class EPacketType extends $pb.ProtobufEnum {
  static const EPacketType None = EPacketType._(0, _omitEnumNames ? '' : 'None');
  static const EPacketType GetSharedFilesReq = EPacketType._(1, _omitEnumNames ? '' : 'GetSharedFilesReq');
  static const EPacketType GetSharedFilesRsp = EPacketType._(2, _omitEnumNames ? '' : 'GetSharedFilesRsp');
  static const EPacketType SharedFileContentNotify = EPacketType._(3, _omitEnumNames ? '' : 'SharedFileContentNotify');
  static const EPacketType FileTransferCompleteNotify = EPacketType._(4, _omitEnumNames ? '' : 'FileTransferCompleteNotify');

  static const $core.List<EPacketType> values = <EPacketType> [
    None,
    GetSharedFilesReq,
    GetSharedFilesRsp,
    SharedFileContentNotify,
    FileTransferCompleteNotify,
  ];

  static final $core.List<EPacketType?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 4);
  static EPacketType? valueOf($core.int value) =>  value < 0 || value >= _byValue.length ? null : _byValue[value];

  const EPacketType._(super.value, super.name);
}


const $core.bool _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
