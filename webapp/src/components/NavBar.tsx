import Link from 'next/link';
import { currentActiveUser } from '@/server/utils';
import { buttonVariants } from '@/components/ui/button';
import SignOutButton from '@/components/SignOutButton';

const NavBar = async () => {
  const user = await currentActiveUser();

  return (
    <nav className="bg-blue-500 p-4 shadow-md">
      <div className="container mx-auto flex justify-between items-center">
        <div className="flex items-center">
          <Link href="/" className="text-white text-xl font-bold mr-6">
            YT AWS
          </Link>
          {user && (
            <div className="flex space-x-4">
              <Link
                href="/manage/videos"
                className={buttonVariants({ variant: "ghost", className: "text-white hover:bg-blue-400" })}
              >
                My Videos
              </Link>
              <Link
                href="/manage/add-video"
                className={buttonVariants({ variant: "ghost", className: "text-white hover:bg-blue-400" })}
              >
                Add Video
              </Link>
            </div>
          )}
        </div>
        <div>
          {user ? (
            <div className="flex items-baseline">
              <span className="text-white mr-4 text-xl">{user.username}</span>
              <SignOutButton />
            </div>
          ) : (
            <div>
              <Link 
                href="/sign-in" 
                className={buttonVariants({ variant: "ghost", className: "text-white mr-2 hover:bg-blue-400" })}
              >
                Sign In
              </Link>
              <Link 
                href="/sign-up" 
                className={buttonVariants({ variant: "ghost", className: "text-white hover:bg-blue-400" })}
              >
                Sign Up
              </Link>
            </div>
          )}
        </div>
      </div>
    </nav>
  );
};

export default NavBar;
