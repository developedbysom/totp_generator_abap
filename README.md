# Time Based OTP Generator using ABAP

![image](https://github.com/developedbysom/totp_generator_abap/assets/70325382/0bdc73fa-47c0-4b5a-b5ca-b228d1c29540)

## Context:

To enable Two Factor Authentication while making an API call. In general API provider shares a confidential API key with the consumers. So consumer while making a REST call to the provider side API, the key being passes with header request. So if this API ey gets compromised then to avoid data hacking, 2FA is a good option. With 2FA, extra layer of security can be ensured. 

There are many ways to achive this perhaps like with plenty of open source libraries are there in Node JS, Python Java and so on, but problem is we don't have a ready to consume FM or class in ABAP for such purpose. Hence this custom made solution was developed. 

## The Algo behind Time Based OTP Generator 

This is all about HMAC - Hash based Message Authentication Code which generates a time based token. In general Data Provider company will share a secret key with their consumers. Now consumer has to usesome authenticaor app like for example "Google Authenticator" and link the provdier system using the shared secret key. 
Passing this secret key to HMAC crypto along with the current unix time will create a has key. 

This hash key now to be converted into a decimal figure to get the desired output which is the token value. 

## Constraints:

The secret key should contain only Base32 allowed characters. This is to avoid human error. 
As o or 0 and 1 or l looks very similar and user or consumer can make a mistake to get the secret key correctly. 

*Allowed Base32 characters are: "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"*

![image](https://github.com/developedbysom/totp_generator_abap/assets/70325382/4cb1ca98-2458-4eaf-921c-55cb7f89ba3c)

> Log Table structure:
>
> ![image](https://github.com/developedbysom/totp_generator_abap/assets/70325382/aed6f38d-b8fb-49be-8822-00ce98570a8d)

> Application Outcome:

![image](https://github.com/developedbysom/totp_generator_abap/assets/70325382/c65f4ac6-9c8b-403a-a19e-68e2635ad74a)

