import NextAuth from "next-auth";
import CognitoProvider from "next-auth/providers/cognito";
const handler = NextAuth({
  providers: [
    CognitoProvider({
      clientId: process.env.COGNITO_CLIENT_ID!,
      clientSecret: process.env.COGNITO_CLIENT_SECRET!,
    }),
  ],
});

export { handler as GET, handler as POST };
