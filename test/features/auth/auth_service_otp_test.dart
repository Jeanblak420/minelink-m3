import 'package:flutter_application_1/features/auth/utils/whatsapp_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // AuthService.sendWhatsappOtp/verifyWhatsappOtp pass whatsappToE164(number)
  // as the Supabase `phone`. Lock that contract here.
  test('OTP phone is the E164 form of the WhatsApp number', () {
    expect(whatsappToE164('+27 82 123 4567'), '+27821234567');
  });

  test('blank/garbage number yields empty phone (callers must guard)', () {
    expect(whatsappToE164('   '), '');
  });
}
