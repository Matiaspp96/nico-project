"use client";

import { useState, useEffect , useCallback} from "react";
import { useLensAuth } from "@/hooks/useLensAuth";
import { useAccount } from "wagmi";
import { useAppKit } from "@reown/appkit/react";
import { useToast } from "@/components/shadcn/use-toast";
import { Button } from "@/components/shadcn/button";
import { Loader2 } from "lucide-react";
import { Textarea } from "../shadcn/textarea";
import Image from 'next/image';

interface Comment {
  id: string;
  content: string;
  createdAt: string;
  author: {
    id: string;
    handle: string;
    displayName?: string;
    picture?: string;
  };
  stats: {
    reactions: number;
    comments: number;
    mirrors: number;
  };
}

interface PageInfo {
  next?: string;
  prev?: string;
}

interface CommentsSectionProps {
  tokenAddress: string;
}

export function CommentsSection({ tokenAddress }: CommentsSectionProps) {
  const { open } = useAppKit();
  const { isConnected } = useAccount();
  const { authenticate, profile, loading: authLoading } = useLensAuth();
  const { toast } = useToast();

  const [comment, setComment] = useState("");
  const [isPosting, setIsPosting] = useState(false);
  const [comments, setComments] = useState<Comment[]>([]);
  const [loadingComments, setLoadingComments] = useState(false);
  const [pageInfo, setPageInfo] = useState<PageInfo>({});

  // Cargar comentarios al montar el componente y cuando cambie el tokenAddress
  useEffect(() => {
    const load = async () => {
      await loadComments();
    };
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tokenAddress]);

  const loadComments = useCallback(async (cursor?: string) => {
    try {
      setLoadingComments(true);
      const url = `/api/lens/comments/${tokenAddress}${cursor ? `?cursor=${cursor}` : ''}`;
      const response = await fetch(url);
      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error);
      }

      setComments(prev => cursor ? [...prev, ...data.comments] : data.comments);
      setPageInfo(data.pageInfo);
    } catch (error) {
      console.error('Error loading comments:', error);
      toast({
        title: "Error",
        description: "Failed to load comments",
        variant: "destructive"
      });
    } finally {
      setLoadingComments(false);
    }
  }, [tokenAddress, toast]);

  const handleConnect = async () => {
    try {
      if (!isConnected) {
        open();
      } else if (!profile) {
        await authenticate();
      }
    } catch (error) {
      console.error("Error connecting:", error);
      toast({
        title: "Error",
        description: "Failed to connect. Please try again.",
        variant: "destructive",
      });
    }
  };

  const handleSubmitComment = useCallback(async (e: React.FormEvent) => {
    e.preventDefault();
    if (!comment.trim() || !profile || isPosting) return;

    try {
      setIsPosting(true);
      const response = await fetch("/api/lens/post", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          content: comment.trim(),
          tokenAddress,
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || "Failed to post comment");
      }

      toast({
        title: "Success",
        description: "Comment posted successfully!",
      });

      setComment("");
      await loadComments();
    } catch (error) {
      console.error("Error posting comment:", error);
      toast({
        title: "Error",
        description:
          error instanceof Error ? error.message : "Failed to post comment",
        variant: "destructive",
      });
    } finally {
      setIsPosting(false);
    }
  }, [comment, profile, isPosting, tokenAddress, toast, loadComments]);

  return (
    <section className="p-6 bg-white shadow-lg rounded-lg border border-gray-200">
      {/* Header */}
      <div className="flex justify-between items-center mb-6">
        <h3 className="text-lg font-semibold">Comments</h3>

        {authLoading ? (
          <Button disabled variant="outline" size="sm">
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            Loading...
          </Button>
        ) : profile ? (
          <div className="flex items-center gap-2">
            {profile.picture && (
              <Image
  src={profile.picture}
  alt={profile.handle}
  width={32}
  height={32}
  className="rounded-full"
/>
            )}
            <span className="font-medium">{profile.handle}</span>
          </div>
        ) : (
          <Button onClick={handleConnect} variant="default" size="sm">
            {isConnected ? "Connect Lens" : "Connect Wallet"}
          </Button>
        )}
      </div>

      {/* Comment Form */}
      {profile && (
        <form onSubmit={handleSubmitComment} className="space-y-4">
          <Textarea
            value={comment}
            onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) =>
              setComment(e.target.value)
            }
            placeholder="Write your comment..."
            className="min-h-[100px]"
          />
          <Button
            type="submit"
            className="w-full"
            disabled={isPosting || !comment.trim()}
          >
            {isPosting ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Posting...
              </>
            ) : (
              "Post Comment"
            )}
          </Button>
        </form>
      )}

      {/* Comments List */}
      <div className="mt-8 space-y-4">
        {loadingComments && comments.length === 0 ? (
          <div className="flex justify-center py-4">
            <Loader2 className="h-6 w-6 animate-spin text-gray-400" />
          </div>
        ) : comments.length > 0 ? (
          <>
            {comments.map((comment) => (
              <div key={comment.id} className="p-4 border rounded-lg">
                <div className="flex items-center gap-2 mb-2">
                  {comment.author.picture && (
                    <Image
                    src={comment.author.picture}
                    alt={comment.author.handle}
                    width={32}
                    height={32}
                    className="rounded-full"
                  />
                  )}
                  <div>
                    <p className="font-medium">
                      {comment.author.displayName || comment.author.handle}
                    </p>
                    <p className="text-sm text-gray-500">
                      {new Date(comment.createdAt).toLocaleDateString()}
                    </p>
                  </div>
                </div>
                <p className="text-gray-700">{comment.content}</p>
                <div className="flex gap-4 mt-2 text-sm text-gray-500">
                  <span>{comment.stats.reactions} reactions</span>
                  <span>{comment.stats.comments} replies</span>
                  <span>{comment.stats.mirrors} mirrors</span>
                </div>
              </div>
            ))}

            {loadingComments && (
              <div className="flex justify-center py-4">
                <Loader2 className="h-6 w-6 animate-spin text-gray-400" />
              </div>
            )}

            {pageInfo.next && !loadingComments && (
              <Button
                variant="outline"
                className="w-full"
                onClick={() => loadComments(pageInfo.next)}
              >
                Load More
              </Button>
            )}
          </>
        ) : (
          <p className="text-center text-gray-500">
            No comments yet. Be the first to comment!
          </p>
        )}
      </div>
    </section>
  );
}