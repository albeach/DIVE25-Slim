// /frontend/src/components/DocumentForm.tsx
import { useState } from 'react';
import { documentService } from '@/services/api';

const CLEARANCE_LEVELS = [
    'UNCLASSIFIED',
    'RESTRICTED',
    'NATO CONFIDENTIAL',
    'NATO SECRET',
    'COSMIC TOP SECRET'
];

const COI_TAGS = [
    'OpAlpha',
    'OpBravo',
    'OpGamma',
    'MissionX',
    'MissionZ'
];

const RELEASABLE_TO = [
    'NATO',
    'EU',
    'FVEY',
    'PARTNERX'
];

interface DocumentFormProps {
    onSuccess?: () => void;
    onCancel?: () => void;
}

export const DocumentForm = ({ onSuccess, onCancel }: DocumentFormProps) => {
    const [formData, setFormData] = useState({
        title: '',
        content: '',
        clearance: 'UNCLASSIFIED',
        releasableTo: ['NATO'],
        coiTags: [] as string[]
    });

    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState(false);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        setError(null);

        try {
            await documentService.createDocument(formData);
            onSuccess?.();
        } catch (err: any) {
            setError(err.response?.data?.error || 'Failed to create document');
        } finally {
            setLoading(false);
        }
    };

    return (
        <form onSubmit={handleSubmit} className="space-y-4">
            <div>
                <label className="block text-sm font-medium text-gray-700">Title</label>
                <input
                    type="text"
                    value={formData.title}
                    onChange={e => setFormData({...formData, title: e.target.value})}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
                    required
                />
            </div>

            <div>
                <label className="block text-sm font-medium text-gray-700">Content</label>
                <textarea
                    value={formData.content}
                    onChange={e => setFormData({...formData, content: e.target.value})}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
                    rows={6}
                    required
                />
            </div>

            <div>
                <label className="block text-sm font-medium text-gray-700">Clearance</label>
                <select
                    value={formData.clearance}
                    onChange={e => setFormData({...formData, clearance: e.target.value})}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
                >
                    {CLEARANCE_LEVELS.map(level => (
                        <option key={level} value={level}>{level}</option>
                    ))}
                </select>
            </div>

            <div>
                <label className="block text-sm font-medium text-gray-700">Releasable To</label>
                <div className="mt-1 space-y-2">
                    {RELEASABLE_TO.map(entity => (
                        <label key={entity} className="inline-flex items-center mr-4">
                            <input
                                type="checkbox"
                                checked={formData.releasableTo.includes(entity)}
                                onChange={e => {
                                    const newReleasableTo = e.target.checked
                                        ? [...formData.releasableTo, entity]
                                        : formData.releasableTo.filter(x => x !== entity);
                                    setFormData({...formData, releasableTo: newReleasableTo});
                                }}
                                className="rounded border-gray-300 text-blue-600"
                            />
                            <span className="ml-2">{entity}</span>
                        </label>
                    ))}
                </div>
            </div>

            <div>
                <label className="block text-sm font-medium text-gray-700">COI Tags</label>
                <div className="mt-1 space-y-2">
                    {COI_TAGS.map(tag => (
                        <label key={tag} className="inline-flex items-center mr-4">
                            <input
                                type="checkbox"
                                checked={formData.coiTags.includes(tag)}
                                onChange={e => {
                                    const newTags = e.target.checked
                                        ? [...formData.coiTags, tag]
                                        : formData.coiTags.filter(x => x !== tag);
                                    setFormData({...formData, coiTags: newTags});
                                }}
                                className="rounded border-gray-300 text-blue-600"
                            />
                            <span className="ml-2">{tag}</span>
                        </label>
                    ))}
                </div>
            </div>

            {error && (
                <div className="text-red-600 text-sm">{error}</div>
            )}

            <div className="flex justify-end space-x-2">
                {onCancel && (
                    <button
                        type="button"
                        onClick={onCancel}
                        className="px-4 py-2 border rounded-md shadow-sm"
                        disabled={loading}
                    >
                        Cancel
                    </button>
                )}
                <button
                    type="submit"
                    className="px-4 py-2 bg-blue-600 text-white rounded-md shadow-sm hover:bg-blue-700"
                    disabled={loading}
                >
                    {loading ? 'Creating...' : 'Create Document'}
                </button>
            </div>
        </form>
    );
};