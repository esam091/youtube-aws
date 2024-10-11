import {cookies} from 'next/headers'
import { currentActiveUser } from '@/server/utils';

export default async function ServerSidePage() {
  const currentUser = await currentActiveUser();

  if (currentUser) {
    return <div>user id: {currentUser.userId}</div>
  }

  return <div>No user</div>
}