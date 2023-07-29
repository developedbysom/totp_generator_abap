# Time Based OTP Generator using ABAP

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
