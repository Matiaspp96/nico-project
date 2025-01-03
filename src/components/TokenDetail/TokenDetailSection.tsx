import { TokenInfo } from "./ProfileInfo";
import { Rating } from "./Rating";
import { StatsGrid } from "./StatsGrid";

interface TokenDetailSectionProps {
  name: string;
  description: string;
  rating: number;
  stats: Array<{ label: string; value: string }>;
}

export function TokenDetailSection({
  name,
  description,
  rating,
  stats,
}: TokenDetailSectionProps) {
  return (
    <section className="space-y-4 bg-white shadow-lg rounded-lg border border-gray-200">
      <div className="flex items-center justify-between px-6 pt-6">
        <TokenInfo name={name} description={description} />
        <Rating value={rating} />
      </div>
      <StatsGrid stats={stats} />
    </section>
  );
}
