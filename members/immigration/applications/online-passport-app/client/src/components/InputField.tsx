import { FormFieldWrapper } from "./form-field-wrapper";
import { Input } from "./ui/input";

export const InputField = ({ label, value, source, onChange }: { label: string; value: string; source?: string; onChange: (e: React.ChangeEvent<HTMLInputElement>) => void }) => (
    <FormFieldWrapper label={label}>
      <div className="relative">
        <Input value={value} onChange={onChange} className="bg-gray-50 text-gray-700" />
        <div className="absolute right-3 top-1/2 -translate-y-1/2 flex gap-2 align-center">
          {source && <span className="text-xs text-gray-500">{source}</span>}
        </div>
      </div>
    </FormFieldWrapper>
)