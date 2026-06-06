import 'package:framelean/application/services/input_runtime/proprietary_audio_format_resolver.dart';
import 'package:framelean/domain/enums/proprietary_audio_format.dart';

class FileExtensionProprietaryAudioFormatResolver
    implements ProprietaryAudioFormatResolver {
  const FileExtensionProprietaryAudioFormatResolver();

  @override
  ProprietaryAudioFormat? resolve(String inputPath) {
    return ProprietaryAudioFormat.fromPath(inputPath);
  }
}
