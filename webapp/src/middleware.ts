import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { currentActiveUser } from '@/server/utils';

export async function middleware(request: NextRequest) {
  const user = await currentActiveUser();
  const isLoggedIn = !!user;
  const path = request.nextUrl.pathname;

  // Protect /manage/* routes
  if (path.startsWith('/manage/') && !isLoggedIn) {
    return NextResponse.redirect(new URL('/sign-in', request.url));
  }

  // Redirect logged-in users away from /sign-in and /sign-up
  if ((path === '/sign-in' || path === '/sign-up') && isLoggedIn) {
    return NextResponse.redirect(new URL('/', request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/manage/:path*', '/sign-in', '/sign-up'],
};